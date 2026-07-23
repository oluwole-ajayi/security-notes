# Conditional Access Baseline Audit

A read-only PowerShell audit for three Microsoft Entra Conditional Access
baselines:

1. Block legacy authentication.
2. Protect privileged administrator roles with MFA or an authentication
   strength.
3. Require compliant devices for defined sensitive applications.

The script reads Conditional Access policy configuration through Microsoft
Graph. It does not create, update, enable, disable, or delete policies.

## Why this exists

The presence of a policy name does not prove that a control is implemented
correctly. A policy can be disabled, left in report-only mode, scoped to the
wrong users, limited to unrelated applications, or configured with an `OR`
operator that makes a control optional.

This audit evaluates policy state, assignments, resource scope, grant controls,
role coverage, exclusions, and selected application coverage.

## Audit statuses

| Status | Meaning |
| --- | --- |
| `PRESENT` | The required configuration is covered by one or more enabled policies. |
| `REPORT-ONLY` | The required configuration is covered, but complete coverage depends on policies that are not enforced. |
| `PARTIAL` | A related policy exists, but its state, scope, exclusions, role coverage, application coverage, or grant logic does not satisfy the baseline. |
| `MISSING` | No active or report-only policy provides the relevant control. |

The overall status is reported as:

- `BASELINE PRESENT`
- `BASELINE REPORT-ONLY`
- `BASELINE PARTIAL`
- `BASELINE INCOMPLETE`

## What the script checks

### 1. Block legacy authentication

The audit looks for an enabled or report-only policy with:

- All users included.
- All resources included.
- Exchange ActiveSync clients selected.
- Other legacy clients selected.
- Block access as a required grant control.
- No unrecognised resource or user exclusions.

### 2. Protect privileged administrator roles

The audit combines coverage across matching policies and checks the 14
high-impact roles recommended in Microsoft's administrator authentication
guidance:

- Global Administrator
- Application Administrator
- Authentication Administrator
- Billing Administrator
- Cloud Application Administrator
- Conditional Access Administrator
- Exchange Administrator
- Helpdesk Administrator
- Password Administrator
- Privileged Authentication Administrator
- Privileged Role Administrator
- Security Administrator
- SharePoint Administrator
- User Administrator

A qualifying policy must:

- Target one or more of the required directory roles.
- Target all resources.
- Require built-in MFA or an authentication strength that satisfies MFA.
- Use valid exclusions when expected emergency-access object IDs are supplied.

Coverage is calculated across all qualifying policies rather than assuming one
policy must contain all 14 roles.

### 3. Require compliant devices

The audit looks for an enabled or report-only policy with:

- All users included.
- `compliantDevice` configured as a required grant control.
- The required sensitive application IDs included.
- No conflicting application exclusion.
- No unrecognised user exclusion.

If `-SensitiveAppId` is omitted, only an all-resources compliant-device policy
can fully satisfy the check. A policy targeting selected applications is
reported as `PARTIAL` until the intended application IDs are supplied.

## Prerequisites

- PowerShell 7 or later.
- Microsoft Graph PowerShell SDK modules:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.SignIns`
- A work or school account that can read Conditional Access policies.
- Delegated Microsoft Graph permission: `Policy.Read.All`.
- Microsoft Entra ID P1 or higher to configure Conditional Access policies.
- Microsoft Intune and working compliance policies before enforcing a
  compliant-device control.

The audit itself remains read-only. It does not require
`Policy.ReadWrite.ConditionalAccess`.

## Install the required modules

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser
```

The current release was tested with:

- PowerShell `7.6.4`
- `Microsoft.Graph.Authentication` `2.38.1`
- `Microsoft.Graph.Identity.SignIns` `2.38.1`

## Connect to Microsoft Graph

```powershell
Connect-MgGraph -Scopes 'Policy.Read.All' -NoWelcome
```

Confirm the delegated permission:

```powershell
$context = Get-MgContext

[pscustomobject]@{
    Connected        = ($null -ne $context)
    HasPolicyReadAll = ($context.Scopes -contains 'Policy.Read.All')
}
```

## Usage

Run the default console audit:

```powershell
./Audit-CAPolicyBaseline.ps1
```

Verify a compliant-device policy that targets the Office 365 application
suite:

```powershell
./Audit-CAPolicyBaseline.ps1 -SensitiveAppId 'Office365'
```

Verify multiple sensitive applications:

```powershell
./Audit-CAPolicyBaseline.ps1 `
    -SensitiveAppId @(
        'Office365'
        '00000003-0000-0ff1-ce00-000000000000'
    )
```

Verify expected emergency-access user or group exclusions:

```powershell
./Audit-CAPolicyBaseline.ps1 `
    -EmergencyAccessObjectId @(
        '<EMERGENCY-ACCESS-OBJECT-ID-1>'
        '<EMERGENCY-ACCESS-OBJECT-ID-2>'
    )
```

Combine both checks:

```powershell
./Audit-CAPolicyBaseline.ps1 `
    -EmergencyAccessObjectId @(
        '<EMERGENCY-ACCESS-OBJECT-ID-1>'
        '<EMERGENCY-ACCESS-OBJECT-ID-2>'
    ) `
    -SensitiveAppId 'Office365'
```

Do not publish real tenant object IDs in screenshots, documentation, issues, or
sample output.

## JSON output

Generate machine-readable output:

```powershell
./Audit-CAPolicyBaseline.ps1 `
    -SensitiveAppId 'Office365' `
    -OutputFormat Json
```

Save the output:

```powershell
./Audit-CAPolicyBaseline.ps1 `
    -SensitiveAppId 'Office365' `
    -OutputFormat Json |
    Set-Content -Path './audit-result.json' -Encoding utf8NoBOM
```

Example structure:

```json
{
  "AuditTimestamp": "2026-07-23T18:00:00.0000000Z",
  "OverallStatus": "BASELINE REPORT-ONLY",
  "TotalPolicies": 3,
  "BaselineChecks": [
    {
      "Baseline": "Block legacy authentication",
      "Status": "REPORT-ONLY",
      "MatchedPolicies": [
        "CA001 - Block legacy authentication"
      ]
    }
  ]
}
```

Tenant IDs and account names are not included in the audit output.

## Example console result

```text
Conditional Access Baseline Audit
================================================
Policies retrieved: 3
Overall status:     BASELINE REPORT-ONLY

[REPORT-ONLY] Block legacy authentication
[REPORT-ONLY] Protect privileged administrator roles
[REPORT-ONLY] Require compliant devices

Read-only audit completed. No tenant settings were changed.
```

## Emergency-access exclusions

Microsoft recommends maintaining at least two cloud-only emergency-access
accounts protected with independent phishing-resistant credentials.

Report-only policies do not enforce access controls and do not require
emergency-access exclusions. Before enabling a policy, create, secure, test,
monitor, and exclude the approved emergency-access accounts or group.

Passing `-EmergencyAccessObjectId` makes the audit verify the expected
exclusions and flag additional user or group exclusions.

Do not create password-only Global Administrator accounts merely to make an
audit pass.

## Compliant-device warning

The presence of a Conditional Access grant control does not prove that device
compliance is operational.

Before enforcing a compliant-device policy:

1. Configure Microsoft Intune compliance policies.
2. Enrol representative devices.
3. Confirm that at least one supported device reports as compliant.
4. Review policy impact and sign-in logs.
5. Validate emergency access.
6. Move from report-only to enforcement through a controlled rollout.

## Limitations

- This is a configuration audit, not a penetration test or guarantee of
  effective enforcement.
- It does not evaluate sign-in logs, report-only impact results, or actual user
  authentication methods.
- It does not confirm that targeted users hold the required licences.
- It does not inspect Intune enrolment, compliance policy assignments, or
  device health.
- It does not resolve group membership or determine whether an excluded user
  currently holds a protected role.
- Custom authentication strengths are recognised when Microsoft Graph reports
  that they satisfy MFA, with a display-name fallback for compatible SDK
  responses.
- A selected-application compliant-device policy requires
  `-SensitiveAppId` for exact application coverage.
- Conditional Access does not cover custom roles or administrative-unit-scoped
  roles in the same way as the built-in directory roles checked here.
- A technically matching report-only policy is not an enforced security
  control.

## Safe deployment guidance

- Begin new Conditional Access policies in report-only mode.
- Review interactive and non-interactive sign-in activity before blocking
  legacy authentication.
- Register administrators for the required authentication methods before
  enforcing an authentication strength.
- Use secured emergency-access accounts before enforcing policies that could
  block administrative access.
- Validate application dependencies before restricting selected resources.
- Use staged deployment groups when moving from report-only to enforcement.

## Evidence handling

Raw evidence should remain private. It can contain tenant identifiers, account
names, application IDs, resource names, or portal navigation details.

This project ignores its local `evidence/` directory. Only deliberately
redacted screenshots should ever be added to public documentation.

## References

- [Microsoft Entra Conditional Access overview](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)
- [Block legacy authentication](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-block-legacy-authentication)
- [Require phishing-resistant MFA for administrators](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-admin-phish-resistant-mfa)
- [Require device compliance](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-all-users-device-compliance)
- [Manage emergency-access accounts](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)
- [Get-MgIdentityConditionalAccessPolicy](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.identity.signins/get-mgidentityconditionalaccesspolicy)

## Author

Oluwole Ajayi  
[GitHub: oluwole-ajayi](https://github.com/oluwole-ajayi)

## License

Licensed under the repository's MIT License.
