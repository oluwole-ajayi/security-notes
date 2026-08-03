targetScope = 'resourceGroup'

@description('Azure region used for the monitoring resources.')
param location string = resourceGroup().location

@description('Name of the central Log Analytics workspace.')
param logAnalyticsWorkspaceName string

@description('Log Analytics data-retention period in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags applied to the monitoring resources.')
param tags object = {
  environment: 'lab'
  workload: 'security-monitoring'
  managedBy: 'Bicep'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output workspaceResourceGroup string = resourceGroup().name
