@description('VirtualNetwork name')
param networkName string

param remoteNetworkIds array

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: networkName
}

resource VirtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' =[ for id in remoteNetworkIds: {
  name: last(split(id, '/'))
  parent: VirtualNetwork
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
