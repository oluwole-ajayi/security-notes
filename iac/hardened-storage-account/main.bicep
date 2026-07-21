metadata name = 'Hardened Azure Storage Account'
metadata description = 'Deploys an Azure Storage Account with hardened defaults for network access, authentication, encryption, data protection, and monitoring.'
metadata owner = 'Oluwole Ajayi'
metadata repository = 'https://github.com/oluwole-ajayi/security-notes'
metadata version = '1.0.0'

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------

@description('The name of the storage account. Must be globally unique, 3-24 characters, and contain lowercase letters and numbers only.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('The Azure region in which to deploy the storage account.')
param location string = resourceGroup().location

@description('Additional tags to apply to the storage account.')
param tags object = {}

@description('The replication SKU for the StorageV2 account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Standard_GZRS'
])
param skuName string = 'Standard_LRS'

@description('The full resource ID of the Log Analytics workspace used for diagnostic logs and metrics.')
param logAnalyticsWorkspaceId string

@description('Set to true only when public network access is required through selected subnet or IP firewall rules. Leave false when using private endpoints or when no data-plane access is currently required.')
param enableSelectedNetworks bool = false

@description('Virtual network subnet resource IDs permitted when selected-network access is enabled.')
param allowedSubnetIds array = []

@description('Public IP addresses or CIDR ranges permitted when selected-network access is enabled.')
param allowedIpRanges array = []

@description('Controls whether trusted Azure services may bypass the storage firewall. None is the strictest default.')
@allowed([
  'None'
  'AzureServices'
])
param networkBypass string = 'None'

@description('Number of days to retain deleted blobs and deleted containers.')
@minValue(1)
@maxValue(365)
param softDeleteRetentionDays int = 30

@description('Number of days to retain Blob Storage change-feed records.')
@minValue(1)
@maxValue(365)
param changeFeedRetentionDays int = 90

// -----------------------------------------------------------------------------
// Variables
// -----------------------------------------------------------------------------

var defaultTags = {
  environment: 'lab'
  workload: 'cloud-security-lab-01'
  managedBy: 'Bicep'
  securityBaseline: 'hardened'
}

var effectiveTags = union(defaultTags, tags)

var publicNetworkAccessMode = enableSelectedNetworks ? 'Enabled' : 'Disabled'

// -----------------------------------------------------------------------------
// Storage account
// -----------------------------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: effectiveTags

  sku: {
    name: skuName
  }

  kind: 'StorageV2'

  properties: {
    accessTier: 'Hot'

    // Control 1:
    // Disabled by default. When enabled, the firewall remains default-deny
    // and permits only the subnet and IP rules supplied to this template.
    publicNetworkAccess: publicNetworkAccessMode

    // Control 2:
    // Prevent anonymous public access to blobs and containers.
    allowBlobPublicAccess: false

    // Control 3:
    // Disable account-key and Shared Key authorisation.
    allowSharedKeyAccess: false

    // Prefer Microsoft Entra ID/OAuth authentication in supported clients.
    defaultToOAuthAuthentication: true

    // Control 4:
    // Reject TLS versions below TLS 1.2.
    minimumTlsVersion: 'TLS1_2'

    // Require encrypted transport.
    supportsHttpsTrafficOnly: true

    // Prevent object replication across Microsoft Entra tenants.
    allowCrossTenantReplication: false

    // Disable local SFTP users and protocols not required by this lab.
    isLocalUserEnabled: false
    isSftpEnabled: false
    isNfsV3Enabled: false

    // Default-deny network firewall.
    networkAcls: {
      defaultAction: 'Deny'
      bypass: networkBypass

      virtualNetworkRules: [
        for subnetId in allowedSubnetIds: {
          id: subnetId
          action: 'Allow'
        }
      ]

      ipRules: [
        for ipRange in allowedIpRanges: {
          value: ipRange
          action: 'Allow'
        }
      ]
    }

    // Microsoft-managed keys with an additional infrastructure-encryption layer.
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true

      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
  }
}

// -----------------------------------------------------------------------------
// Blob data-protection controls
// -----------------------------------------------------------------------------

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'

  properties: {
    isVersioningEnabled: true

    changeFeed: {
      enabled: true
      retentionInDays: changeFeedRetentionDays
    }

    deleteRetentionPolicy: {
      enabled: true
      days: softDeleteRetentionDays
      allowPermanentDelete: false
    }

    containerDeleteRetentionPolicy: {
      enabled: true
      days: softDeleteRetentionDays
    }
  }
}

// -----------------------------------------------------------------------------
// Diagnostic settings
// -----------------------------------------------------------------------------

resource storageAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: 'storage-account-security-diagnostics'

  properties: {
    workspaceId: logAnalyticsWorkspaceId

    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobServices
  name: 'blob-security-diagnostics'

  properties: {
    workspaceId: logAnalyticsWorkspaceId

    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]

    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------

output storageAccountId string = storageAccount.id
output deployedStorageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output publicNetworkAccess string = publicNetworkAccessMode
output sharedKeyAccessEnabled bool = false
output minimumTlsVersion string = 'TLS1_2'
output logAnalyticsWorkspaceResourceId string = logAnalyticsWorkspaceId
