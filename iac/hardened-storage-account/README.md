# Hardened Azure Storage Account

A reusable Bicep template for deploying an Azure `StorageV2` account with security-hardened defaults for network access, authentication, encryption, data protection, and monitoring.

This project is part of **Cloud Security Lab #1** in the `security-notes` repository.

> This template is informed by recognised cloud security guidance. It is a technical lab and does not represent formal compliance certification.

## Lab objective

Azure Storage accounts can appear private while still allowing more network or authentication access than intended.

This lab demonstrates four controls that organisations should review when deploying Azure Storage:

1. Public network access
2. Selected network and private endpoint access
3. Minimum TLS version
4. Shared Key authorisation

The controls are defined in Bicep so that the secure configuration can be reviewed, repeated, and tested consistently.

## What this template enforces

### 1. Public network access disabled by default

The storage account is deployed with:

```bicep
publicNetworkAccess: 'Disabled'
```

Public data-plane access remains disabled unless `enableSelectedNetworks` is explicitly set to `true`.

With public network access disabled, access should be provided through a separately configured private endpoint when the storage account needs to be reached from a virtual network.

### 2. Default-deny network firewall

The storage firewall uses:

```bicep
defaultAction: 'Deny'
```

When selected-network access is enabled, only the subnet IDs and IP ranges explicitly supplied to the deployment are added as allow rules.

Trusted Azure-service bypass is disabled by default and can only be enabled through the `networkBypass` parameter.

### 3. Shared Key authorisation disabled

The template sets:

```bicep
allowSharedKeyAccess: false
```

Applications and administrators should use Microsoft Entra ID and Azure role-based access control for supported data-plane access.

Account SAS and service SAS tokens signed with the storage account key are not accepted. User-delegation SAS can still be used where supported and appropriately authorised through Microsoft Entra ID.

### 4. TLS 1.2 and HTTPS required

The account rejects connections using TLS versions below TLS 1.2:

```bicep
minimumTlsVersion: 'TLS1_2'
supportsHttpsTrafficOnly: true
```

This prevents unencrypted HTTP access and reduces exposure to legacy transport protocols.

## Additional security controls

The template also configures:

* Anonymous blob and container access disabled
* Cross-tenant object replication disabled
* Microsoft Entra ID selected as the preferred portal authentication method
* Local storage users disabled
* SFTP disabled
* NFS 3.0 disabled
* Microsoft-managed encryption keys
* Infrastructure encryption enabled
* Blob versioning enabled
* Blob change feed enabled
* Blob soft delete enabled
* Container soft delete enabled
* Blob read, write, and delete diagnostic categories sent to Log Analytics
* Storage account transaction metrics sent to Log Analytics
* Default security and workload tags

## Data protection defaults

| Control                             | Default  |
| ----------------------------------- | -------- |
| Blob versioning                     | Enabled  |
| Change feed                         | Enabled  |
| Change-feed retention               | 90 days  |
| Blob soft delete                    | Enabled  |
| Blob soft-delete retention          | 30 days  |
| Container soft delete               | Enabled  |
| Container soft-delete retention     | 30 days  |
| Blob Permanent deletion during retention | Disabled |

Retention periods can be changed through deployment parameters.

## Security guidance alignment

The following mapping is informative and describes the security intent of the template.

| Template control                                 | NIST CSF 2.0 | NCSC Cloud Security Principles |
| ------------------------------------------------ | ------------ | ------------------------------ |
| Public network access and default-deny firewall  | PR.PS, PR.DS | Principle 1 and Principle 11   |
| Shared Key authorisation disabled                | PR.AA        | Principle 10                   |
| TLS 1.2 and HTTPS-only transport                 | PR.DS        | Principle 1                    |
| Encryption at rest and infrastructure encryption | PR.DS        | Principle 2                    |
| Versioning and soft-delete controls              | PR.IR        | Principle 2                    |
| Diagnostic logging and monitoring                | DE.CM        | Principle 5                    |
| Cross-tenant replication disabled                | PR.DS, PR.AA | Principle 3 and Principle 10   |

Exact CIS Microsoft Azure Foundations Benchmark control numbers are intentionally not listed. Benchmark versions and control numbering can change and should be validated against an authorised copy before making a formal compliance claim.

## Repository structure

```text
security-notes/
└── iac/
    └── hardened-storage-account/
        ├── main.bicep
        └── README.md
```

## Prerequisites

Before deploying the template, confirm that you have:

* An active Azure subscription
* Azure CLI installed
* Bicep CLI installed
* Contributor or Owner permissions on the target resource group
* An existing Log Analytics workspace
* A globally unique storage account name
* A dedicated lab or development tenant

Do not test this template against a client tenant or an important production subscription.

Check the installed tools:

```bash
az version
az bicep version
```

Confirm the active subscription:

```bash
az account show --output table
```

## Validate the Bicep template

Navigate to the module directory:

```bash
cd security-notes/iac/hardened-storage-account
```

Build and validate the Bicep syntax:

```bash
az bicep build --file main.bicep
```

A successful build creates a compiled `main.json` ARM template in the same directory.

The generated JSON file does not need to be committed unless the repository intentionally stores compiled ARM templates.

## Deploy the lab

The following example uses the lab resources created for this project.

Set the resource names:

```bash
RESOURCE_GROUP="rg-security-labs-uksouth"
WORKSPACE_NAME="law-security-labs"
```

Retrieve the Log Analytics workspace resource ID:

```bash
LAW_ID="$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query id \
  --output tsv)"
```

Generate a valid and likely unique storage account name:

```bash
STORAGE_ACCOUNT_NAME="stsec$(date +%s)"
```

Storage account names must:

* Be globally unique
* Contain between 3 and 24 characters
* Use lowercase letters and numbers only
* Contain no spaces, uppercase letters, or hyphens

Confirm the generated values:

```bash
echo "$LAW_ID"
echo "$STORAGE_ACCOUNT_NAME"
```

### Preview the deployment

Run a what-if deployment before creating resources:

```bash
az deployment group what-if \
  --name cloud-security-lab-01-preview \
  --resource-group "$RESOURCE_GROUP" \
  --template-file main.bicep \
  --parameters \
    storageAccountName="$STORAGE_ACCOUNT_NAME" \
    logAnalyticsWorkspaceId="$LAW_ID"
```

Review the proposed changes before continuing.

### Create the deployment

```bash
az deployment group create \
  --name cloud-security-lab-01 \
  --resource-group "$RESOURCE_GROUP" \
  --template-file main.bicep \
  --parameters \
    storageAccountName="$STORAGE_ACCOUNT_NAME" \
    logAnalyticsWorkspaceId="$LAW_ID"
```

The default deployment creates a storage account with public network access disabled.

No private endpoint is created by this template. Until a private endpoint or selected-network configuration is added, the storage account has no permitted public data-plane network path.

## Deploy with selected IP access

Selected-network access must be explicitly enabled.

Replace the example documentation IP address with the public IP address or CIDR range that should be permitted:

```bash
az deployment group create \
  --name cloud-security-lab-01-selected-network \
  --resource-group "$RESOURCE_GROUP" \
  --template-file main.bicep \
  --parameters \
    storageAccountName="$STORAGE_ACCOUNT_NAME" \
    logAnalyticsWorkspaceId="$LAW_ID" \
    enableSelectedNetworks=true \
    allowedIpRanges='["203.0.113.10"]'
```

Do not use broad allow rules such as `0.0.0.0/0`.

## Deploy with an allowed subnet

An existing subnet can be supplied through `allowedSubnetIds`.

The subnet must be correctly configured for Azure Storage access, including the appropriate Microsoft Storage service endpoint where service endpoints are being used.

Example parameter format:

```bash
allowedSubnetIds='[
  "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<subnet-name>"
]'
```

Selected-network access must also be enabled:

```bash
enableSelectedNetworks=true
```

This template does not create:

* A virtual network
* A subnet
* A service endpoint
* A private endpoint
* A private DNS zone

Those resources should be deployed separately or added in a future module.

## Parameters

| Name                      | Type   | Required | Default                 | Description                                              |
| ------------------------- | ------ | -------- | ----------------------- | -------------------------------------------------------- |
| `storageAccountName`      | string | Yes      | —                       | Globally unique storage account name                     |
| `location`                | string | No       | Resource-group location | Azure deployment region                                  |
| `tags`                    | object | No       | `{}`                    | Additional resource tags                                 |
| `skuName`                 | string | No       | `Standard_LRS`          | Storage replication SKU                                  |
| `logAnalyticsWorkspaceId` | string | Yes      | —                       | Full resource ID of the Log Analytics workspace          |
| `enableSelectedNetworks`  | bool   | No       | `false`                 | Enables public access through selected firewall rules    |
| `allowedSubnetIds`        | array  | No       | `[]`                    | Subnet resource IDs added to the storage firewall        |
| `allowedIpRanges`         | array  | No       | `[]`                    | Public IP addresses or CIDR ranges added to the firewall |
| `networkBypass`           | string | No       | `None`                  | Allows no bypass or trusted Azure-service bypass         |
| `softDeleteRetentionDays` | int    | No       | `30`                    | Blob and container soft-delete retention                 |
| `changeFeedRetentionDays` | int    | No       | `90`                    | Blob change-feed retention                               |

Supported values for `skuName` are:

* `Standard_LRS`
* `Standard_GRS`
* `Standard_ZRS`
* `Standard_GZRS`

Supported values for `networkBypass` are:

* `None`
* `AzureServices`

## Outputs

| Name                              | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| `storageAccountId`                | Resource ID of the deployed storage account           |
| `deployedStorageAccountName`      | Name of the deployed storage account                  |
| `primaryBlobEndpoint`             | Primary Blob Storage endpoint                         |
| `publicNetworkAccess`             | Public network access mode selected by the deployment |
| `sharedKeyAccessEnabled`          | Confirms that Shared Key access is disabled           |
| `minimumTlsVersion`               | Minimum TLS version enforced                          |
| `logAnalyticsWorkspaceResourceId` | Log Analytics workspace used for diagnostics          |

## Verify the deployment with Azure CLI

Inspect the important account-level properties:

```bash
az storage account show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --query '{
    publicNetworkAccess:publicNetworkAccess,
    blobPublicAccess:allowBlobPublicAccess,
    sharedKeyAccess:allowSharedKeyAccess,
    minimumTlsVersion:minimumTlsVersion,
    httpsOnly:enableHttpsTrafficOnly,
    crossTenantReplication:allowCrossTenantReplication
  }' \
  --output table
```

For the default deployment, the expected values are:

| Setting                  | Expected value |
| ------------------------ | -------------- |
| Public network access    | `Disabled`     |
| Blob public access       | `false`        |
| Shared Key access        | `false`        |
| Minimum TLS version      | `TLS1_2`       |
| HTTPS only               | `true`         |
| Cross-tenant replication | `false`        |

List the deployed resources:

```bash
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

Review the deployment result:

```bash
az deployment group show \
  --name cloud-security-lab-01 \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

## Verify the deployment in Azure Portal

Open the deployed storage account and inspect the following areas.

### Networking

Navigate to:

```text
Storage account
→ Security + networking
→ Networking
```

Confirm:

* Public network access is disabled for the default deployment
* Default network action is deny
* No unintended IP or virtual-network rules are present
* Trusted Azure-service bypass is not enabled unless deliberately selected

### Configuration

Navigate to:

```text
Storage account
→ Settings
→ Configuration
```

Confirm:

* Allow Blob anonymous access is disabled
* Allow storage account key access is disabled
* Default to Microsoft Entra authorisation is enabled
* Minimum TLS version is 1.2
* Secure transfer required is enabled
* Cross-tenant replication is disabled
* SFTP is disabled
* NFS 3.0 is disabled

### Encryption

Navigate to:

```text
Storage account
→ Security + networking
→ Encryption
```

Confirm:

* Microsoft-managed keys are in use
* Infrastructure encryption is enabled

### Data protection

Navigate to:

```text
Storage account
→ Data management
→ Data protection
```

Confirm:

* Blob soft delete is enabled
* Container soft delete is enabled
* Blob versioning is enabled
* Blob change feed is enabled
* Retention periods match the deployment parameters

### Diagnostic settings

Navigate to the storage account’s monitoring and diagnostic settings.

Confirm that the deployment created:

* `storage-account-security-diagnostics`
* `blob-security-diagnostics`

The Blob service diagnostic setting enables:

* `StorageRead`
* `StorageWrite`
* `StorageDelete`

Diagnostic tables will not necessarily contain records immediately. Relevant storage operations must occur after diagnostic settings have been enabled before log records can be generated.

## Important authentication note

Because Shared Key authorisation is disabled, commands or applications that rely on the storage account key may fail.

Use Microsoft Entra authentication where supported.

For Azure CLI Blob Storage operations, use:

```bash
--auth-mode login
```

Example:

```bash
az storage container list \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login
```

The signed-in identity must also have an appropriate data-plane role, such as:

```text
Storage Blob Data Reader
Storage Blob Data Contributor
Storage Blob Data Owner
```

Contributor access to the Azure resource does not automatically grant permission to read or modify the data stored inside it.

## Known limitations

* The template deploys a storage account, not an entire network architecture.
* No private endpoint or private DNS zone is created.
* Public data-plane access is completely disabled by default.
* Selected-network access requires `enableSelectedNetworks=true`.
* Supplying an allowlist without enabling selected-network access does not make the account publicly reachable.
* Subnet rules may require an Azure Storage service endpoint to be configured on the subnet.
* No Azure RBAC data-plane role assignments are created.
* Customer-managed keys are not included in this version.
* Diagnostic resource logs are configured for Blob Storage only.
* File, Queue, and Table data-plane diagnostic logs are not configured.
* Infrastructure encryption is selected at account creation and cannot later be enabled or disabled on the same account.
* `defaultToOAuthAuthentication` changes the preferred authentication method in supported Azure experiences; it is not a replacement for RBAC or an access-control policy.
* Disabling Shared Key access can break legacy applications, scripts, account SAS tokens, and service SAS tokens that depend on the storage account key.

## Future enhancements

Potential extensions for later labs include:

* Private endpoint deployment
* Private DNS integration
* VNet and subnet deployment
* Azure Policy enforcement
* Microsoft Defender for Storage
* Customer-managed keys through Azure Key Vault
* User-assigned managed identity
* Azure RBAC role assignments
* Queue, File, and Table diagnostic settings
* Diagnostic alerts and Microsoft Sentinel analytics
* Automated deployment validation tests

## Cleanup

Delete only the lab storage account while retaining the shared resource group and Log Analytics workspace for future labs:

```bash
az storage account delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --yes
```

Review the resource group afterwards:

```bash
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

## Author

[Oluwole Ajayi](https://github.com/oluwole-ajayi) — Cybersecurity Consultant & Founder of [Techlync Solutions](https://techlynsolutions.co.uk/) and [VeriLync](https://verilync.com/).

## License

MIT — see [the security-notes root LICENSE](https://github.com/oluwole-ajayi/security-notes/blob/main/LICENSE).