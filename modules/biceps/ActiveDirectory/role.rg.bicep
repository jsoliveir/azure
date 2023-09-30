targetScope = 'resourceGroup'

param roleDefinitions object

param resourceId string

param identity string 

resource RoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing =[ for role in items(roleDefinitions): {
  name: role.value
}]

resource RoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [ for (role,i) in  items(roleDefinitions): {
  name: guid(resourceId, RoleDefinition[i].id)
  properties: {
    roleDefinitionId:  RoleDefinition[i].id
    principalType: 'ServicePrincipal'
    principalId: identity
  }
}]
