# Azure Landing-Zone Security Baseline with Bicep

A subscription-scoped Azure security baseline that deploys central monitoring and assigns four security guardrails as code.

This is a focused lab implementation, not a complete enterprise-scale Azure landing zone. Production landing zones normally also include management-group hierarchy, identity, networking, subscription vending, budgets and operational governance.

## Security model

Good policy-as-code does not mean setting every control to `Deny`. The policy effect should match the control objective:

| Control | Effect | Behaviour |
| --- | --- | --- |
| Prevent public IPs on network interfaces | `Deny` | Blocks NICs associated with public IP addresses |
| Require HTTPS for Azure Storage | `Deny` | Blocks storage accounts that permit insecure HTTP traffic |
| Require customer-managed keys for Storage | `Audit` | Reports storage accounts using Microsoft-managed keys |
| Configure Storage diagnostic settings | `DeployIfNotExists` | Deploys diagnostic settings to central Log Analytics |

The standard Azure built-in CMK policy supports `Audit` and `Disabled`, not `Deny`. The diagnostic policy uses a managed identity because it must deploy settings on existing and future resources.

## Architecture

The deployment creates:

- A central monitoring resource group
- A Log Analytics workspace
- Four subscription-level Azure Policy assignments
- A system-assigned identity for the diagnostic policy
- `Monitoring Contributor` at subscription scope
- `Log Analytics Contributor` restricted to the workspace

## Repository structure

```text
azure-landing-zone/
├── README.md
├── main.bicep
├── examples/
│   ├── allowed-storage.bicep
│   └── denied-storage.bicep
└── modules/
    ├── monitoring.bicep
    ├── policy-assignments.bicep
    └── workspace-rbac.bicep
```

## Built-in policies

| Policy | Definition ID |
| --- | --- |
| Network interfaces should not have public IPs | `83a86a26-fd1f-447c-b59d-e51f44264114` |
| Secure transfer to storage accounts should be enabled | `404c3081-a854-4457-ae30-26a93ef643f9` |
| Storage accounts should use customer-managed key for encryption | `6fac406b-40ca-413b-bf8e-0bf964659c25` |
| Configure diagnostic settings for Storage Accounts to Log Analytics workspace | `59759c62-9a22-4cdf-ae64-074495983fef` |

## Prerequisites

- An Azure subscription
- Azure CLI
- Azure Bicep CLI
- Permission to create:
  - Subscription policy assignments
  - Resource groups and Log Analytics workspaces
  - Role assignments

For this lab, an Azure subscription `Owner` has the required permissions. In a production environment, use appropriately separated policy and access-administration roles.

Confirm the active subscription:

```powershell
az account show `
    --query '{Subscription:name,State:state,Tenant:tenantDisplayName}' `
    -o table
```

## Validate locally

```powershell
az bicep build `
    --file "./main.bicep" `
    --stdout |
    Out-Null
```

## Preview the deployment

```powershell
az deployment sub what-if `
    --name "alz-security-baseline-preview" `
    --location "uksouth" `
    --template-file "./main.bicep" `
    --parameters location="uksouth"
```

## Deploy

```powershell
az deployment sub create `
    --name "alz-security-baseline" `
    --location "uksouth" `
    --template-file "./main.bicep" `
    --parameters location="uksouth" `
    --query '{
        Deployment:name,
        Status:properties.provisioningState
    }' `
    -o table
```

## Verify the policy assignments

```powershell
az policy assignment list `
    --query "[?starts_with(name, 'alz-')].{
        Name:name,
        DisplayName:displayName,
        Enforcement:enforcementMode
    }" `
    -o table
```

Expected assignments:

```text
alz-deny-nic-public-ip
alz-deny-storage-http
alz-audit-storage-cmk
alz-deploy-storage-diag
```

## Validate the preventive policy

Create a test resource group:

```powershell
$testResourceGroup = "rg-alz-policy-tests-uksouth"

az group create `
    --name $testResourceGroup `
    --location "uksouth"
```

### Deployment allowed

The allowed example enables HTTPS-only traffic and passes the preventive Storage policy:

```powershell
az deployment group create `
    --resource-group $testResourceGroup `
    --name "allowed-storage-test" `
    --template-file "./examples/allowed-storage.bicep" `
    --query '{
        Deployment:name,
        Status:properties.provisioningState,
        StorageAccount:properties.outputs.storageAccountName.value
    }' `
    -o table
```

This example intentionally uses Microsoft-managed encryption keys. It passes the preventive HTTPS control but is expected to appear as non-compliant under the CMK audit policy.

### Deployment denied

The denied example sets `supportsHttpsTrafficOnly` to `false`:

```powershell
az deployment group create `
    --resource-group $testResourceGroup `
    --name "denied-storage-test" `
    --template-file "./examples/denied-storage.bicep"
```

Expected policy result:

```text
RequestDisallowedByPolicy
Storage accounts must require HTTPS traffic.
```

The denial should reference:

```text
alz-deny-storage-http
```

## Trigger a compliance scan

Azure Policy compliance evaluation is asynchronous.

```powershell
az policy state trigger-scan `
    --resource-group $testResourceGroup `
    --no-wait
```

After evaluation completes, review the resource in Azure Policy to confirm:

- HTTPS policy compliance
- CMK audit non-compliance
- Diagnostic-setting deployment

## Verify diagnostic settings

```powershell
$storageId = az storage account show `
    --resource-group $testResourceGroup `
    --name "<storage-account-name>" `
    --query id `
    -o tsv

$diagnosticSettingsUrl = "https://management.azure.com${storageId}/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"

az rest `
    --method get `
    --url $diagnosticSettingsUrl `
    --query "value[].{
        Name:name,
        Workspace:properties.workspaceId,
        MetricsEnabled:properties.metrics[0].enabled
    }" `
    -o table
```

## Important limitations

- This is a minimal subscription security baseline, not a complete enterprise landing zone.
- The public-IP policy blocks public IP association on network interfaces. It does not prevent creation of every standalone Public IP resource.
- The standard Storage CMK policy is detective (`Audit`), not preventive.
- The diagnostic policy configures the Storage account diagnostic setting with metrics enabled.
- Complete Storage data-plane logging requires additional diagnostic policies for Blob, File, Queue and Table services.
- Policy compliance and `DeployIfNotExists` remediation can take time to appear.
- Log Analytics ingestion may create Azure charges.

## Cleanup

The following removes only resources and assignments created by this lab.

Capture the diagnostic-policy identity and remove its RBAC assignments before deleting the policy assignment:

```powershell
$diagnosticPrincipalId = az policy assignment show `
    --name "alz-deploy-storage-diag" `
    --query identity.principalId `
    -o tsv

$diagnosticRoleAssignmentIds = @(
    az role assignment list `
        --all `
        --query "[?principalId=='$diagnosticPrincipalId'].id" `
        -o tsv
)

$diagnosticRoleAssignmentIds |
    ForEach-Object {
        az role assignment delete --ids $_
    }

@(
    "alz-deny-nic-public-ip"
    "alz-deny-storage-http"
    "alz-audit-storage-cmk"
    "alz-deploy-storage-diag"
) |
    ForEach-Object {
        az policy assignment delete --name $_
    }

az group delete `
    --name "rg-alz-policy-tests-uksouth" `
    --yes `
    --no-wait

az group delete `
    --name "rg-alz-monitoring-uksouth" `
    --yes `
    --no-wait
```

## References

- [Azure Policy built-in definitions](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies)
- [Azure Storage policy reference](https://learn.microsoft.com/azure/storage/common/policy-reference)
- [Azure Monitor diagnostic-settings policies](https://learn.microsoft.com/azure/azure-monitor/platform/diagnostic-settings-policy-built-in)
- [Azure landing-zone design areas](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-areas)

