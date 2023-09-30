targetScope = 'subscription'

param roleDefinition string

param resourceId string

param identity string 

resource RoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roleDefinition
}

resource RoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceId, RoleDefinition.id)
  properties: {
    description: '[managed by ${resourceId}}]'
    roleDefinitionId: RoleDefinition.id
    principalType: 'ServicePrincipal'
    principalId: identity
  }
}
