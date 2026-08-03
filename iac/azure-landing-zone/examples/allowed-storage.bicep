targetScope = 'resourceGroup'

@description('Azure region for the test storage account.')
param location string = resourceGroup().location

@description('Globally unique name for the storage account.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'stlzallowed${uniqueString(subscription().id, resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: {
    environment: 'lab'
    testType: 'allowed-by-preventive-policy'
    managedBy: 'Bicep'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Disabled'
    accessTier: 'Hot'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output expectedPreventiveResult string = 'Allowed'
output cmkAuditNote string = 'This example uses Microsoft-managed keys and is intentionally visible to the CMK audit policy.'
