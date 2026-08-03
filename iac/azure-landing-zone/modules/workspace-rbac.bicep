targetScope = 'resourceGroup'

@description('Name of the existing Log Analytics workspace.')
param logAnalyticsWorkspaceName string

@description('Object ID of the diagnostic-policy managed identity.')
param diagnosticPolicyPrincipalId string

var logAnalyticsContributorRoleId = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource diagnosticLogAnalyticsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: logAnalyticsWorkspace
  name: guid(logAnalyticsWorkspace.id, diagnosticPolicyPrincipalId, logAnalyticsContributorRoleId)
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsContributorRoleId)
    principalId: diagnosticPolicyPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = diagnosticLogAnalyticsRoleAssignment.id
