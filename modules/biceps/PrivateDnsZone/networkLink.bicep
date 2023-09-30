param virtualNetworksIds array

param name string = deployment().name

resource PrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: name
}

resource PrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (id, i) in virtualNetworksIds: {
  name: last(split(id,'/'))
  location: 'global'
  parent: PrivateDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: id
    }
  }
}]
