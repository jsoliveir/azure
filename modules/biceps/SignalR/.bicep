param location string = resourceGroup().location

param tags object = resourceGroup().tags

param skuName string = 'Standard_S1'

param skuTier string = split(skuName,'_')[0]

param capacity int = 1

param privateDnsZoneId string

param subnetId string 

param clientEndpoint string

resource SignalR 'Microsoft.SignalRService/SignalR@2022-02-01' = {
  name: deployment().name
  location: location
  kind: 'SignalR'
  tags: tags
  sku: {
    capacity: capacity
    name: skuName
    tier: skuTier
  }
  properties: {
    features: [
      { flag: 'ServiceMode', value: 'Default' }
      { flag: 'EnableConnectivityLogs', value: 'True' }
      { flag: 'EnableMessagingLogs', value: 'True' }
      { flag: 'EnableLiveTrace', value: 'False' }
    ]
    cors: {
      allowedOrigins: [ '*' ]
    }
    networkACLs: {
      defaultAction: 'Deny'
      privateEndpoints: [
        {
          name: 'default'
          allow: [
            'ServerConnection'
            'ClientConnection'
            'RESTAPI'
            'Trace'
          ]
        }
      ]
    }
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: false
    disableAadAuth: false
  }
}


resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: SignalR.name
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${SignalR.name}-nic'
    privateLinkServiceConnections: [
      {
        name: SignalR.name
        properties: {
          privateLinkServiceId: SignalR.id
          groupIds: [ 'signalr' ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource PrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = {
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


#disable-next-line outputs-should-not-contain-secrets
output primaryConnectionString string = '${SignalR.listKeys().primaryConnectionString}ClientEndpoint=${clientEndpoint};'
