targetScope = 'resourceGroup'

param tags object = resourceGroup().tags

param location string

@description('{ name<string>: cidr<string> }')
param subnets object

@description('''
{
  destinationAddressPrefix: *
  destinationPortRange: *
  sourceAddressPrefix: *
  sourcePortRange: *
  direction: Inbound
  access: Allow
  protocol: *
}
''')
param securityRules object = {}

param privateDnsZoneIds array = []

@description('{ name<string>: services<string[]> }')
param subnetDelegations object = {}

@description('array of virtual network ids')
param peerings array = []

@description('''[
  Microsoft.KeyVault
  Microsoft.ServiceBus
  Microsoft.Storage
  Microsoft.Sql
]''')
param serviceEndpoints array = []

var virtualNetworkPeerings = [for id in peerings: {
  name: last(split(id, '/'))
  properties: {
    remoteVirtualNetwork: {
      id: id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    doNotVerifyRemoteGateways: false
  }
}]

resource NetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-05-01' = if (length(items(securityRules)) > 0) {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    securityRules: [for (r, i) in items(securityRules): {
      properties: union(
        {
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          priority: (100 * (i + 1))
        }, r.value)
      name: r.key
    }]
  }
}

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    enableDdosProtection: false
    addressSpace: { addressPrefixes: [for subnet in items(subnets): subnet.value] }
    virtualNetworkPeerings: virtualNetworkPeerings
    subnets: [for subnet in items(subnets): {
      name: subnet.key
      properties: {
        privateLinkServiceNetworkPolicies: 'Enabled'
        privateEndpointNetworkPolicies: 'Enabled'
        addressPrefix: subnet.value
        // service endpoints
        serviceEndpoints: map(serviceEndpoints, ep => { service: ep, locations: [ '*' ] })
        // subnet delegations
        delegations: !contains(subnetDelegations,subnet.key) ? [] : map(subnetDelegations[subnet.key], d => {
          properties: { serviceName: d }
          name: uniqueString(d)
        })
        // network security groups
        networkSecurityGroup: length(items(securityRules)) == 0 ? null : {
          id: NetworkSecurityGroup.id
        }
      }
    }]
  }

  resource Peering 'virtualNetworkPeerings' = [for (id, i) in peerings: {
    properties: virtualNetworkPeerings[i].properties
    name: last(split(id, '/'))
  }]
}

module RemoteVirtualNetworkPeering 'peering.bicep' = [for (id, i) in peerings: {
  name: VirtualNetwork.name
  scope: resourceGroup(split(id, '/')[2], split(id, '/')[4])
  params: {
    remoteNetworkIds: [ VirtualNetwork.id ]
    networkName: last(split(id, '/'))
  }
}]

module PrivateDnsZoneLink '../PrivateDnsZone/networkLink.bicep' = [for pdnsz in privateDnsZoneIds: {
  scope: resourceGroup(split(pdnsz, '/')[2], split(pdnsz, '/')[4])
  name: guid(VirtualNetwork.name,pdnsz)
  params: {
    name: last(split(pdnsz, '/'))
    virtualNetworksIds: [ VirtualNetwork.id ]
  }
}]

output id string = VirtualNetwork.id

output name string = VirtualNetwork.name

output location string = VirtualNetwork.location

output subnets array = VirtualNetwork.properties.subnets

output networkSecurityGroupId string = NetworkSecurityGroup.id
