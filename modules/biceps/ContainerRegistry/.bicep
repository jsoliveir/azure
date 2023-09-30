param location string = resourceGroup().location

param acrPullAllowedGroupIds array = []

param sku string = 'Premium'

param adminUser bool = false

resource ContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: deployment().name
  location: location
  properties:{
    anonymousPullEnabled: false
    adminUserEnabled: adminUser
  }
  sku: {
    name: sku
  }
}

resource AcrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in acrPullAllowedGroupIds : {
  name: guid(resourceGroup().id, id, AcrPullRoleDefinition.id)
  properties: {
    roleDefinitionId: AcrPullRoleDefinition.id
    principalType: 'Group'
    principalId: id
  }
}]
