targetScope = 'resourceGroup'

param location string = resourceGroup().location

param tags object = resourceGroup().tags

param subnetId string = ''

param privateDnsZoneId string = ''

@description('{ name: <string>, id : <guid> }')
param adminGroup object

param adminLogin string = '47e4a38b-5ae8-4506-83ba-4d9485244734'

@secure()
param adminPassword string = newGuid()

resource Identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: deployment().name
  location: location
  tags: tags
}

resource MicrosoftSqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  location: location
  name: deployment().name
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${Identity.id}': {}
    }
  }
  properties: {
    administratorLoginPassword: adminPassword
    publicNetworkAccess: empty(subnetId) ? 'Enabled' : 'Disabled'
    primaryUserAssignedIdentityId: Identity.id
    restrictOutboundNetworkAccess: 'Disabled'
    administratorLogin: adminLogin
    minimalTlsVersion: '1.2'
    version: '12.0'
    administrators: {
      administratorType: 'ActiveDirectory'
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: false
      principalType: 'Group'
      login: adminGroup.Name
      sid: adminGroup.id
    }
  }
}

resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = if(!empty(subnetId)) {
  name: MicrosoftSqlServer.name
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${MicrosoftSqlServer.name}-nic'
    privateLinkServiceConnections: [
      {
        name: MicrosoftSqlServer.name
        properties: {
          privateLinkServiceId: MicrosoftSqlServer.id
          groupIds: [ 'sqlServer' ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource PrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if(!empty(privateDnsZoneId)){
  parent: PrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// resource Role 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: '88d8e3e3-8f55-4a1e-953a-9b9898b8876b'
// }

// resource DirectoryReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id,Role.id,MicrosoftSqlServer.id)
//   scope: tenant()
//   properties: {
//     principalId: Identity.properties.principalId
//     principalType: 'ServicePrincipal'
//     roleDefinitionId: Role.id
//   }
// }

output location string = MicrosoftSqlServer.location

output name string = MicrosoftSqlServer.name

output id string = MicrosoftSqlServer.id
