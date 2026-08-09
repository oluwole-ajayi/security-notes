# azure-hardened-blob

A Bicep module for a Blob-focused Azure Storage account with explicit security guardrails. It is paired with [`aws-hardened-s3`](../aws-hardened-s3/) for a technically honest cross-cloud comparison.

## What the module configures

1. Public network access disabled.
2. Blob anonymous access prohibited at account level.
3. HTTPS required and TLS 1.2 minimum.
4. Shared Key authorisation disabled and OAuth selected as the portal default.
5. Cross-tenant replication and local users disabled.
6. Network ACL default deny with no trusted-service bypass.
7. Microsoft-managed encryption plus infrastructure encryption.
8. Blob versioning and configurable blob/container soft delete.

## Prerequisites

- Azure CLI with Bicep support.
- Contributor access to the target resource group.
- A globally unique 3-24 character lowercase alphanumeric storage account name.

## Validate and preview

```powershell
az bicep format `
    --file "./main.bicep"

az bicep build `
    --file "./main.bicep" `
    --stdout |
    Out-Null

az deployment group what-if `
    --resource-group <resource-group> `
    --template-file "./main.bicep" `
    --parameters storageAccountName=<unique-name>
```

## Deploy

```powershell
az deployment group create `
    --resource-group <resource-group> `
    --name "cloud-security-lab-04-azure" `
    --template-file "./main.bicep" `
    --parameters `
        storageAccountName=<unique-name> `
        tags='{"Environment":"lab","Project":"cloud-security-lab-04","ManagedBy":"bicep"}'
```

## Verify the storage account

```powershell
az storage account show `
    --resource-group <resource-group> `
    --name <unique-name> `
    --query "{
        PublicNetworkAccess:publicNetworkAccess,
        BlobPublicAccess:allowBlobPublicAccess,
        SharedKeyAccess:allowSharedKeyAccess,
        OAuthDefault:defaultToOAuthAuthentication,
        HttpsOnly:enableHttpsTrafficOnly,
        MinimumTls:minimumTlsVersion,
        InfrastructureEncryption:encryption.requireInfrastructureEncryption
    }" `
    -o table

az storage account blob-service-properties show `
    --resource-group <resource-group> `
    --account-name <unique-name> `
    --query "{
        Versioning:isVersioningEnabled,
        BlobSoftDelete:deleteRetentionPolicy.days,
        ContainerSoftDelete:containerDeleteRetentionPolicy.days
    }" `
    -o table
```

## Safe comparison example

[`examples/relaxed-guardrails.bicep`](./examples/relaxed-guardrails.bicep) is for `what-if` only. It enables the public network endpoint, permits container-level anonymous access to be configured and uses a network ACL default action of `Allow`. It creates no container and grants no anonymous data access.

Public endpoint reachability and anonymous blob authorisation are separate controls. Do not describe `publicNetworkAccess: 'Enabled'` alone as making blob data public.

## Cross-cloud comparison

| Security intent | Azure Blob Storage | AWS S3 |
| --- | --- | --- |
| Prevent anonymous/public authorisation | `allowBlobPublicAccess: false` | Four S3 Block Public Access settings plus IAM and bucket policies |
| Remove the public network path | `publicNetworkAccess: 'Disabled'` | VPC endpoint plus restrictive bucket/access-point policies; Public Access Block is not a network firewall |
| Enforce HTTPS | `supportsHttpsTrafficOnly: true` | Bucket-policy deny using `aws:SecureTransport` |
| Enforce TLS 1.2 minimum | `minimumTlsVersion: 'TLS1_2'` | Bucket-policy deny using `s3:TlsVersion` |
| Prefer identity-based access | Entra ID/RBAC and `allowSharedKeyAccess: false` | IAM roles, policies, SCPs and resource policies |
| Recover changed/deleted objects | Blob versioning and soft delete | S3 Versioning |

## Important authentication difference

Disabling Azure Shared Key authorisation prevents account-key authorisation and service/account SAS based on those keys. User delegation SAS remains available because it is authorised through Entra ID.

AWS does not expose an equivalent Shared Key toggle. Its IAM credentials and request-signing model should be described on their own terms rather than presented as a one-to-one mapping.

## Relationship to the earlier Azure module

This module is intentionally focused on the cross-cloud object-storage comparison. The existing [`hardened-storage-account`](../hardened-storage-account/) module remains the broader Azure lab implementation with monitoring and additional production considerations.

## Cleanup

Delete only the lab storage account, or remove the dedicated lab resource group if it contains no unrelated resources.

```powershell
az storage account delete `
    --resource-group <resource-group> `
    --name <unique-name> `
    --yes
```

## References

- [Azure Storage account Bicep reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts)
- [Prevent Shared Key authorisation](https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent)
- [Prevent anonymous blob access](https://learn.microsoft.com/en-us/azure/storage/blobs/anonymous-read-access-prevent)
- [Authorise access to Azure Storage](https://learn.microsoft.com/en-us/azure/storage/common/authorize-data-access)


## Deployment validation

- Successfully deploy-tested on 9 August 2026 in `uksouth` with Bicep 0.45.15.
- The resource-group deployment completed successfully and the resulting StorageV2 account was inspected through Azure Resource Manager.
- Verified disabled public-network, anonymous Blob and Shared Key access; OAuth preference; TLS 1.2; default-deny networking; infrastructure encryption; versioning; and 30-day soft delete.
- The relaxed comparison template was evaluated with `what-if` only and was not deployed.

## Author

[Oluwole Ajayi](https://github.com/oluwole-ajayi)
