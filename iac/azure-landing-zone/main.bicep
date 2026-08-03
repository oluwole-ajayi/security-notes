targetScope = 'subscription'

@description('Primary Azure region for the landing-zone monitoring resources.')
param location string = 'uksouth'

@description('Name of the central monitoring resource group.')
param monitoringResourceGroupName string = 'rg-alz-monitoring-${location}'

@description('Name of the central Log Analytics workspace.')
param logAnalyticsWorkspaceName string = 'law-alz-security-${uniqueString(subscription().id)}'

@description('Log Analytics data-retention period in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags applied to resources deployed by the landing-zone baseline.')
param tags object = {
  environment: 'lab'
  workload: 'landing-zone-security'
  managedBy: 'Bicep'
  project: 'Cloud Security Lab 3'
}

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: monitoringResourceGroupName
  location: location
  tags: tags
}

module monitoring './modules/monitoring.bicep' = {
  name: 'deploy-central-monitoring'
  scope: monitoringResourceGroup
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    retentionInDays: retentionInDays
    tags: tags
  }
}

module policyAssignments './modules/policy-assignments.bicep' = {
  name: 'deploy-security-policy-assignments'
  params: {
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

module workspaceRbac './modules/workspace-rbac.bicep' = {
  name: 'assign-diagnostic-workspace-rbac'
  scope: monitoringResourceGroup
  params: {
    logAnalyticsWorkspaceName: monitoring.outputs.workspaceName
    diagnosticPolicyPrincipalId: policyAssignments.outputs.diagnosticPolicyPrincipalId
  }
}

output monitoringResourceGroupId string = monitoringResourceGroup.id
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId

output policyAssignmentIds object = {
  publicIpPrevention: policyAssignments.outputs.publicIpPolicyAssignmentId
  secureStorageTransfer: policyAssignments.outputs.secureTransferPolicyAssignmentId
  customerManagedKeyAudit: policyAssignments.outputs.customerManagedKeyPolicyAssignmentId
  storageDiagnostics: policyAssignments.outputs.diagnosticSettingsPolicyAssignmentId
}

output diagnosticPolicyPrincipalId string = policyAssignments.outputs.diagnosticPolicyPrincipalId
output diagnosticWorkspaceRoleAssignmentId string = workspaceRbac.outputs.roleAssignmentId
