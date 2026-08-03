targetScope = 'subscription'

@description('Azure region used for the managed identity attached to the diagnostic policy.')
param location string

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

var publicIpPolicyId = '83a86a26-fd1f-447c-b59d-e51f44264114'
var secureTransferPolicyId = '404c3081-a854-4457-ae30-26a93ef643f9'
var customerManagedKeyPolicyId = '6fac406b-40ca-413b-bf8e-0bf964659c25'
var diagnosticSettingsPolicyId = '59759c62-9a22-4cdf-ae64-074495983fef'

var monitoringContributorRoleId = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'

resource publicIpPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'alz-deny-nic-public-ip'
  properties: {
    displayName: 'Landing zone - Deny public IPs on network interfaces'
    description: 'Prevents network interfaces from being associated with public IP addresses.'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', publicIpPolicyId)
    enforcementMode: 'Default'
    metadata: {
      category: 'Network Security'
      managedBy: 'Bicep'
    }
    nonComplianceMessages: [
      {
        message: 'Public IP addresses on network interfaces are not permitted by the landing-zone baseline.'
      }
    ]
  }
}

resource secureTransferPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'alz-deny-storage-http'
  properties: {
    displayName: 'Landing zone - Require HTTPS for Storage'
    description: 'Prevents deployment of storage accounts that do not require secure transfer.'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', secureTransferPolicyId)
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
    metadata: {
      category: 'Storage Security'
      managedBy: 'Bicep'
    }
    nonComplianceMessages: [
      {
        message: 'Storage accounts must require HTTPS traffic.'
      }
    ]
  }
}

resource customerManagedKeyPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'alz-audit-storage-cmk'
  properties: {
    displayName: 'Landing zone - Audit Storage CMK encryption'
    description: 'Audits storage accounts that are not encrypted with a customer-managed key.'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', customerManagedKeyPolicyId)
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
    metadata: {
      category: 'Data Protection'
      managedBy: 'Bicep'
    }
    nonComplianceMessages: [
      {
        message: 'Review this storage account because it does not use a customer-managed encryption key.'
      }
    ]
  }
}

resource diagnosticSettingsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'alz-deploy-storage-diag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Landing zone - Deploy Storage diagnostics'
    description: 'Deploys storage-account diagnostic settings to the central Log Analytics workspace.'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', diagnosticSettingsPolicyId)
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      logAnalytics: {
        value: logAnalyticsWorkspaceId
      }
      metricsEnabled: {
        value: true
      }
      profileName: {
        value: 'setByLandingZonePolicy'
      }
    }
    metadata: {
      category: 'Monitoring'
      managedBy: 'Bicep'
    }
    nonComplianceMessages: [
      {
        message: 'Storage diagnostic settings must be connected to the central Log Analytics workspace.'
      }
    ]
  }
}

resource diagnosticMonitoringRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, diagnosticSettingsPolicyAssignment.name, monitoringContributorRoleId)
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', monitoringContributorRoleId)
    principalId: diagnosticSettingsPolicyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output publicIpPolicyAssignmentId string = publicIpPolicyAssignment.id
output secureTransferPolicyAssignmentId string = secureTransferPolicyAssignment.id
output customerManagedKeyPolicyAssignmentId string = customerManagedKeyPolicyAssignment.id
output diagnosticSettingsPolicyAssignmentId string = diagnosticSettingsPolicyAssignment.id
output diagnosticPolicyPrincipalId string = diagnosticSettingsPolicyAssignment.identity.principalId
