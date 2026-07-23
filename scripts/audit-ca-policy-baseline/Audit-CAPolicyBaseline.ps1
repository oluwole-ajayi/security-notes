<#
.SYNOPSIS
    Audits three Microsoft Entra Conditional Access baselines.

.DESCRIPTION
    Performs a read-only assessment of:

      1. Blocking legacy authentication for all users and resources
      2. Requiring MFA or an authentication strength for 14 privileged roles
      3. Requiring compliant devices for sensitive applications

    Results are reported as PRESENT, REPORT-ONLY, PARTIAL, or MISSING.
    The script reads policy configuration only and does not change the tenant.

.PARAMETER OutputFormat
    Console (default) or Json.

.PARAMETER EmergencyAccessObjectId
    Optional object IDs for approved emergency-access users or groups. When
    supplied, the audit verifies that these objects are excluded where expected
    and flags additional unrecognised user or group exclusions.

.PARAMETER SensitiveAppId
    Optional application IDs that must be covered by the compliant-device
    baseline. If omitted, an all-resources policy can pass, while a policy
    targeting only selected applications is reported as PARTIAL.

.EXAMPLE
    Connect-MgGraph -Scopes 'Policy.Read.All'
    ./Audit-CAPolicyBaseline.ps1

.EXAMPLE
    ./Audit-CAPolicyBaseline.ps1 `
        -EmergencyAccessObjectId '00000000-0000-0000-0000-000000000000' `
        -SensitiveAppId '00000003-0000-0ff1-ce00-000000000000'

.EXAMPLE
    ./Audit-CAPolicyBaseline.ps1 -OutputFormat Json |
        Set-Content -Path './audit-result.json'

.NOTES
    Author  : Oluwole Ajayi
    Project : https://github.com/oluwole-ajayi/security-notes
    License : MIT
    Scope   : Policy.Read.All
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Write-Host is limited to the interactive Console output mode; Json mode writes pipeline output.'
)]
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Console', 'Json')]
    [string] $OutputFormat = 'Console',

    [Parameter()]
    [ValidateNotNull()]
    [string[]] $EmergencyAccessObjectId = @(),

    [Parameter()]
    [ValidateNotNull()]
    [string[]] $SensitiveAppId = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ValueArray {
    param([AllowNull()] $Value)

    if ($null -eq $Value) {
        return @()
    }

    return @($Value | Where-Object { $null -ne $_ -and "$_".Length -gt 0 })
}

function Test-ContainsValue {
    param(
        [AllowNull()] $Values,
        [Parameter(Mandatory)]
        [string] $Expected
    )

    return @(
        ConvertTo-ValueArray $Values |
            Where-Object { "$_" -ieq $Expected }
    ).Count -gt 0
}

function Get-PolicyStateRank {
    param([string] $State)

    switch ($State) {
        'enabled'                         { return 2 }
        'enabledForReportingButNotEnforced' { return 1 }
        default                           { return 0 }
    }
}

function Test-AllResourcesScope {
    param($Policy)

    $apps = $Policy.Conditions.Applications
    if ($null -eq $apps) {
        return $false
    }

    $includesAll = Test-ContainsValue $apps.IncludeApplications 'All'
    $excludedApps = @(ConvertTo-ValueArray $apps.ExcludeApplications)
    $hasExcludedApps = $excludedApps.Count -gt 0

    return $includesAll -and -not $hasExcludedApps
}

function Get-PolicyExclusion {
    param($Policy)

    $users = $Policy.Conditions.Users
    if ($null -eq $users) {
        return @()
    }

    return @(
        ConvertTo-ValueArray $users.ExcludeUsers
        ConvertTo-ValueArray $users.ExcludeGroups
    ) | Select-Object -Unique
}

function Test-ExpectedExclusion {
    param(
        $Policy,
        [string[]] $ExpectedObjectId,
        [switch] $RequireExpected
    )

    $actual = @(Get-PolicyExclusion $Policy)
    $expected = @(ConvertTo-ValueArray $ExpectedObjectId | Select-Object -Unique)

    if ($expected.Count -eq 0) {
        return [PSCustomObject]@{
            Valid             = ($actual.Count -eq 0)
            ExpectedVerified  = $false
            MissingExpected   = @()
            Unexpected        = $actual
        }
    }

    $missing = @(
        $expected | Where-Object { $_ -notin $actual }
    )
    $unexpected = @(
        $actual | Where-Object { $_ -notin $expected }
    )

    return [PSCustomObject]@{
        Valid             = (
            $unexpected.Count -eq 0 -and
            (-not $RequireExpected -or $missing.Count -eq 0)
        )
        ExpectedVerified  = ($missing.Count -eq 0)
        MissingExpected   = $missing
        Unexpected        = $unexpected
    }
}

function Test-ControlIsRequired {
    param(
        $GrantControls,
        [Parameter(Mandatory)]
        [string] $Control
    )

    if ($null -eq $GrantControls) {
        return $false
    }

    $builtIns = @(ConvertTo-ValueArray $GrantControls.BuiltInControls)
    if (-not (Test-ContainsValue $builtIns $Control)) {
        return $false
    }

    $customControls = @(
        ConvertTo-ValueArray $GrantControls.CustomAuthenticationFactors
    )
    $termsOfUse = @(ConvertTo-ValueArray $GrantControls.TermsOfUse)

    $controlCount = $builtIns.Count
    $controlCount += $customControls.Count
    $controlCount += $termsOfUse.Count

    if (Test-AuthenticationStrengthConfigured $GrantControls.AuthenticationStrength) {
        $controlCount++
    }

    return $controlCount -eq 1 -or $GrantControls.Operator -ieq 'AND'
}

function Test-AuthenticationStrengthConfigured {
    param([AllowNull()] $AuthenticationStrength)

    if ($null -eq $AuthenticationStrength) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace("$($AuthenticationStrength.Id)")) {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace("$($AuthenticationStrength.DisplayName)")) {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace("$($AuthenticationStrength.RequirementsSatisfied)")) {
        return $true
    }

    return @(
        ConvertTo-ValueArray $AuthenticationStrength.AllowedCombinations
    ).Count -gt 0
}

function Test-MfaControl {
    param($GrantControls)

    if ($null -eq $GrantControls) {
        return $false
    }

    if (Test-ControlIsRequired $GrantControls 'mfa') {
        return $true
    }

    $strength = $GrantControls.AuthenticationStrength
    if (-not (Test-AuthenticationStrengthConfigured $strength)) {
        return $false
    }

    if ($strength.RequirementsSatisfied -ieq 'mfa') {
        return $true
    }

    # Fallback for responses that omit RequirementsSatisfied.
    return $strength.DisplayName -match '(?i)(mfa|multifactor|passwordless|phishing)'
}

function Get-AuthenticationControlDescription {
    param($GrantControls)

    if (Test-AuthenticationStrengthConfigured $GrantControls.AuthenticationStrength) {
        $displayName = $GrantControls.AuthenticationStrength.DisplayName
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            return 'Authentication strength'
        }
        return "Authentication strength: $displayName"
    }

    if (Test-ContainsValue $GrantControls.BuiltInControls 'mfa') {
        return 'Built-in MFA'
    }

    return 'Unknown'
}

function ConvertTo-AuditResult {
    param(
        [string] $Baseline,
        [ValidateSet('PRESENT', 'REPORT-ONLY', 'PARTIAL', 'MISSING')]
        [string] $Status,
        [string] $Detail,
        [string[]] $MatchedPolicies = @(),
        [hashtable] $Evidence = @{}
    )

    return [PSCustomObject]@{
        Baseline       = $Baseline
        Status         = $Status
        Detail         = $Detail
        MatchedPolicies = @($MatchedPolicies | Select-Object -Unique)
        Evidence       = [PSCustomObject] $Evidence
    }
}

function Test-BlockLegacyAuthentication {
    param(
        [object[]] $Policies,
        [string[]] $EmergencyIds
    )

    $candidates = @(
        $Policies | Where-Object {
            (Get-PolicyStateRank $_.State) -gt 0 -and
            (Test-ContainsValue $_.Conditions.ClientAppTypes 'exchangeActiveSync') -and
            (Test-ContainsValue $_.Conditions.ClientAppTypes 'other') -and
            (Test-ControlIsRequired $_.GrantControls 'block')
        }
    )

    if ($candidates.Count -eq 0) {
        return ConvertTo-AuditResult `
            -Baseline 'Block legacy authentication' `
            -Status 'MISSING' `
            -Detail 'No active or report-only policy blocks both legacy client-app categories.'
    }

    $exact = @(
        $candidates | Where-Object {
            $includeAllUsers = Test-ContainsValue $_.Conditions.Users.IncludeUsers 'All'
            $allResources = Test-AllResourcesScope $_
            $exclusions = Test-ExpectedExclusion $_ $EmergencyIds -RequireExpected
            $includeAllUsers -and $allResources -and $exclusions.Valid
        }
    )

    $enabled = @($exact | Where-Object { $_.State -eq 'enabled' })
    if ($enabled.Count -gt 0) {
        return ConvertTo-AuditResult `
            -Baseline 'Block legacy authentication' `
            -Status 'PRESENT' `
            -Detail 'An enabled policy blocks Exchange ActiveSync and other legacy clients for all users and resources.' `
            -MatchedPolicies $enabled.DisplayName `
            -Evidence @{ CandidateCount = $candidates.Count; ExactMatchCount = $enabled.Count }
    }

    $reportOnly = @(
        $exact | Where-Object { $_.State -eq 'enabledForReportingButNotEnforced' }
    )
    if ($reportOnly.Count -gt 0) {
        return ConvertTo-AuditResult `
            -Baseline 'Block legacy authentication' `
            -Status 'REPORT-ONLY' `
            -Detail 'The baseline is configured correctly but is not yet enforced.' `
            -MatchedPolicies $reportOnly.DisplayName `
            -Evidence @{ CandidateCount = $candidates.Count; ExactMatchCount = $reportOnly.Count }
    }

    return ConvertTo-AuditResult `
        -Baseline 'Block legacy authentication' `
        -Status 'PARTIAL' `
        -Detail 'A legacy-authentication block exists, but its user scope, resource scope, or exclusions do not meet the baseline.' `
        -MatchedPolicies $candidates.DisplayName `
        -Evidence @{ CandidateCount = $candidates.Count; ExactMatchCount = 0 }
}

function Test-PrivilegedRoleMfa {
    param(
        [object[]] $Policies,
        [System.Collections.IDictionary] $CriticalRoles,
        [string[]] $EmergencyIds
    )

    $candidatePolicies = @(
        $Policies | Where-Object {
            $includedRoles = @(
                ConvertTo-ValueArray $_.Conditions.Users.IncludeRoles
            )
            (Get-PolicyStateRank $_.State) -gt 0 -and
            (Test-MfaControl $_.GrantControls) -and
            $includedRoles.Count -gt 0
        }
    )

    if ($candidatePolicies.Count -eq 0) {
        return ConvertTo-AuditResult `
            -Baseline 'Protect privileged administrator roles' `
            -Status 'MISSING' `
            -Detail 'No active or report-only policy requires MFA or an authentication strength for directory roles.' `
            -Evidence @{ RequiredRoleCount = $CriticalRoles.Count; CoveredRoleCount = 0 }
    }

    $eligible = @(
        $candidatePolicies | Where-Object {
            (Test-AllResourcesScope $_) -and
            (Test-ExpectedExclusion $_ $EmergencyIds -RequireExpected).Valid
        }
    )

    function Get-CoveredRole {
        param([object[]] $InputPolicies)

        $covered = @()
        foreach ($policy in $InputPolicies) {
            $included = @(ConvertTo-ValueArray $policy.Conditions.Users.IncludeRoles)
            $excluded = @(ConvertTo-ValueArray $policy.Conditions.Users.ExcludeRoles)
            $covered += @(
                $included | Where-Object {
                    $_ -in $CriticalRoles.Keys -and $_ -notin $excluded
                }
            )
        }
        return @($covered | Select-Object -Unique)
    }

    $enabledEligible = @($eligible | Where-Object { $_.State -eq 'enabled' })
    $enabledCoverage = @(Get-CoveredRole $enabledEligible)
    $combinedCoverage = @(Get-CoveredRole $eligible)
    $requiredRoleIds = @($CriticalRoles.Keys)

    $enabledMissing = @($requiredRoleIds | Where-Object { $_ -notin $enabledCoverage })
    $combinedMissing = @($requiredRoleIds | Where-Object { $_ -notin $combinedCoverage })

    $controlDescriptions = @(
        $candidatePolicies |
            ForEach-Object { Get-AuthenticationControlDescription $_.GrantControls } |
            Select-Object -Unique
    )

    if ($enabledMissing.Count -eq 0) {
        return ConvertTo-AuditResult `
            -Baseline 'Protect privileged administrator roles' `
            -Status 'PRESENT' `
            -Detail 'All 14 recommended privileged roles are covered by enabled policies targeting all resources.' `
            -MatchedPolicies $enabledEligible.DisplayName `
            -Evidence @{
                RequiredRoleCount = $CriticalRoles.Count
                CoveredRoleCount  = $enabledCoverage.Count
                MissingRoles      = @()
                Controls          = $controlDescriptions
            }
    }

    if ($combinedMissing.Count -eq 0) {
        $reportOnlyNames = @(
            $eligible |
                Where-Object { $_.State -eq 'enabledForReportingButNotEnforced' } |
                Select-Object -ExpandProperty DisplayName
        )
        return ConvertTo-AuditResult `
            -Baseline 'Protect privileged administrator roles' `
            -Status 'REPORT-ONLY' `
            -Detail 'All 14 roles are covered only when report-only policies are included; the complete baseline is not yet enforced.' `
            -MatchedPolicies $reportOnlyNames `
            -Evidence @{
                RequiredRoleCount = $CriticalRoles.Count
                CoveredRoleCount  = $combinedCoverage.Count
                MissingRoles      = @()
                Controls          = $controlDescriptions
            }
    }

    $missingRoleNames = @(
        $combinedMissing | ForEach-Object { $CriticalRoles[$_] }
    )

    return ConvertTo-AuditResult `
        -Baseline 'Protect privileged administrator roles' `
        -Status 'PARTIAL' `
        -Detail "$($combinedCoverage.Count) of $($CriticalRoles.Count) recommended roles are covered with valid all-resource scope." `
        -MatchedPolicies $candidatePolicies.DisplayName `
        -Evidence @{
            RequiredRoleCount = $CriticalRoles.Count
            CoveredRoleCount  = $combinedCoverage.Count
            MissingRoles      = $missingRoleNames
            Controls          = $controlDescriptions
        }
}

function Test-CompliantDevice {
    param(
        [object[]] $Policies,
        [string[]] $EmergencyIds,
        [string[]] $RequiredAppIds
    )

    $candidates = @(
        $Policies | Where-Object {
            (Get-PolicyStateRank $_.State) -gt 0 -and
            (Test-ControlIsRequired $_.GrantControls 'compliantDevice') -and
            (Test-ContainsValue $_.Conditions.Users.IncludeUsers 'All') -and
            (Test-ExpectedExclusion $_ $EmergencyIds -RequireExpected).Valid
        }
    )

    if ($candidates.Count -eq 0) {
        return ConvertTo-AuditResult `
            -Baseline 'Require compliant devices' `
            -Status 'MISSING' `
            -Detail 'No active or report-only policy requires a compliant device for all users.' `
            -Evidence @{ RequiredApplications = $RequiredAppIds; CoveredApplications = @() }
    }

    function Test-PolicyCoversApp {
        param($Policy, [string] $AppId)

        $apps = $Policy.Conditions.Applications
        if ($null -eq $apps) {
            return $false
        }

        if (Test-ContainsValue $apps.ExcludeApplications $AppId) {
            return $false
        }

        return (
            (Test-ContainsValue $apps.IncludeApplications 'All') -or
            (Test-ContainsValue $apps.IncludeApplications $AppId)
        )
    }

    function Get-CoveredRequiredApp {
        param([object[]] $InputPolicies)

        if ($RequiredAppIds.Count -eq 0) {
            if (@($InputPolicies | Where-Object { Test-AllResourcesScope $_ }).Count -gt 0) {
                return @('All')
            }
            return @()
        }

        $covered = foreach ($appId in $RequiredAppIds) {
            if (@($InputPolicies | Where-Object { Test-PolicyCoversApp $_ $appId }).Count -gt 0) {
                $appId
            }
        }
        return @($covered | Select-Object -Unique)
    }

    $enabled = @($candidates | Where-Object { $_.State -eq 'enabled' })
    $enabledCoverage = @(Get-CoveredRequiredApp $enabled)
    $combinedCoverage = @(Get-CoveredRequiredApp $candidates)
    $expectedCount = if ($RequiredAppIds.Count -eq 0) { 1 } else { $RequiredAppIds.Count }

    if ($enabledCoverage.Count -eq $expectedCount) {
        return ConvertTo-AuditResult `
            -Baseline 'Require compliant devices' `
            -Status 'PRESENT' `
            -Detail 'An enabled compliant-device policy covers the required application scope for all users.' `
            -MatchedPolicies $enabled.DisplayName `
            -Evidence @{
                RequiredApplications = $(if ($RequiredAppIds.Count -eq 0) { @('All resources') } else { $RequiredAppIds })
                CoveredApplications  = $enabledCoverage
            }
    }

    if ($combinedCoverage.Count -eq $expectedCount) {
        return ConvertTo-AuditResult `
            -Baseline 'Require compliant devices' `
            -Status 'REPORT-ONLY' `
            -Detail 'The required application scope is covered only when report-only policies are included.' `
            -MatchedPolicies $candidates.DisplayName `
            -Evidence @{
                RequiredApplications = $(if ($RequiredAppIds.Count -eq 0) { @('All resources') } else { $RequiredAppIds })
                CoveredApplications  = $combinedCoverage
            }
    }

    $detail = if ($RequiredAppIds.Count -eq 0) {
        'A compliant-device policy exists, but it targets selected applications. Supply -SensitiveAppId to verify the intended applications.'
    }
    else {
        "$($combinedCoverage.Count) of $($RequiredAppIds.Count) specified sensitive applications are covered."
    }

    return ConvertTo-AuditResult `
        -Baseline 'Require compliant devices' `
        -Status 'PARTIAL' `
        -Detail $detail `
        -MatchedPolicies $candidates.DisplayName `
        -Evidence @{
            RequiredApplications = $RequiredAppIds
            CoveredApplications  = $combinedCoverage
        }
}

# Microsoft-recommended high-impact directory role template IDs.
$criticalRoles = [ordered]@{
    '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
    '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' = 'Application Administrator'
    'c4e39bd9-1100-46d3-8c65-fb160da0071f' = 'Authentication Administrator'
    'b0f54661-2d74-4c50-afa3-1ec803f12efe' = 'Billing Administrator'
    '158c047a-c907-4556-b7ef-446551a6b5f7' = 'Cloud Application Administrator'
    'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' = 'Conditional Access Administrator'
    '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
    '729827e3-9c14-49f7-bb1b-9608f156bbb8' = 'Helpdesk Administrator'
    '966707d0-3269-4727-9be2-8c3a10f19b9d' = 'Password Administrator'
    '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' = 'Privileged Authentication Administrator'
    'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
    '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
    'f28a1f50-f6e7-4571-818b-6a12f2af6b6c' = 'SharePoint Administrator'
    'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
}

# Preflight.
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    throw 'Microsoft.Graph.Authentication is not installed.'
}
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.SignIns)) {
    throw 'Microsoft.Graph.Identity.SignIns is not installed.'
}

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop

$context = Get-MgContext
if ($null -eq $context) {
    throw "No Microsoft Graph session. Run: Connect-MgGraph -Scopes 'Policy.Read.All'"
}
if ('Policy.Read.All' -notin $context.Scopes) {
    throw "The current session lacks Policy.Read.All. Run: Disconnect-MgGraph; Connect-MgGraph -Scopes 'Policy.Read.All'"
}

Write-Verbose 'Retrieving Conditional Access policies.'
$allPolicies = @(Get-MgIdentityConditionalAccessPolicy -All)

$results = @(
    Test-BlockLegacyAuthentication `
        -Policies $allPolicies `
        -EmergencyIds $EmergencyAccessObjectId

    Test-PrivilegedRoleMfa `
        -Policies $allPolicies `
        -CriticalRoles $criticalRoles `
        -EmergencyIds $EmergencyAccessObjectId

    Test-CompliantDevice `
        -Policies $allPolicies `
        -EmergencyIds $EmergencyAccessObjectId `
        -RequiredAppIds $SensitiveAppId
)

$overallStatus = if ($results.Status -contains 'MISSING') {
    'BASELINE INCOMPLETE'
}
elseif ($results.Status -contains 'PARTIAL') {
    'BASELINE PARTIAL'
}
elseif ($results.Status -contains 'REPORT-ONLY') {
    'BASELINE REPORT-ONLY'
}
else {
    'BASELINE PRESENT'
}

$auditOutput = [PSCustomObject]@{
    AuditTimestamp = (Get-Date).ToUniversalTime().ToString('o')
    OverallStatus  = $overallStatus
    TotalPolicies  = $allPolicies.Count
    BaselineChecks = $results
}

if ($OutputFormat -eq 'Json') {
    $auditOutput | ConvertTo-Json -Depth 10
    return
}

$statusColours = @{
    'PRESENT'     = 'Green'
    'REPORT-ONLY' = 'Cyan'
    'PARTIAL'     = 'Yellow'
    'MISSING'     = 'Red'
}

Write-Host ''
Write-Host 'Conditional Access Baseline Audit' -ForegroundColor Cyan
Write-Host ('=' * 48) -ForegroundColor Cyan
Write-Host "Policies retrieved: $($allPolicies.Count)"
Write-Host "Overall status:     $overallStatus"
Write-Host ''

foreach ($check in $results) {
    Write-Host "[$($check.Status)] " `
        -NoNewline `
        -ForegroundColor $statusColours[$check.Status]
    Write-Host $check.Baseline
    Write-Host "  $($check.Detail)"

    if ($check.MatchedPolicies.Count -gt 0) {
        Write-Host '  Matched policies:'
        foreach ($policyName in $check.MatchedPolicies) {
            Write-Host "    - $policyName"
        }
    }

    $missingRolesProperty = $check.Evidence.PSObject.Properties['MissingRoles']
    if ($null -ne $missingRolesProperty) {
        $missingRoles = @($missingRolesProperty.Value)
        if ($missingRoles.Count -gt 0) {
            Write-Host '  Missing roles:'
            foreach ($roleName in $missingRoles) {
                Write-Host "    - $roleName"
            }
        }
    }

    Write-Host ''
}

Write-Host 'Read-only audit completed. No tenant settings were changed.' -ForegroundColor DarkGray
