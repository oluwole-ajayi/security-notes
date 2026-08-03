targetScope = 'resourceGroup'

@description('Azure region for the test storage account.')
param location string = resourceGroup().location

@description('Globally unique name for the storage account.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'stlzdenied${uniqueString(subscription().id, resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: {
    environment: 'lab'
    testType: 'expected-policy-denial'
    managedBy: 'Bicep'
  }
  properties: {
    supportsHttpsTrafficOnly: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Disabled'
    accessTier: 'Hot'
  }
}

output expectedResult string = 'Denied by Azure Policy because HTTPS-only traffic is disabled.'
