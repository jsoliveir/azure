targetScope = 'resourceGroup'

var config = loadYamlContent('main.yml')

var localPeerings = map(items(config.azure.peerings),n => {local: n.key, remotes: n.value})

module PeeringLocal '../../../modules/azure/biceps/VirtualNetwork/peering.bicep' = [for network in localPeerings : {
  name: guid(join(network.remotes,network.local))
  scope: resourceGroup(config.azure.networks[network.local].subscription, config.azure.networks[network.local].resourceGroup)
  params: {
    networkName: network.local
    remoteNetworkIds: map(network.remotes, remote => resourceId(
      config.azure.networks[remote].subscription, 
      config.azure.networks[remote].resourceGroup,
      'Microsoft.Network/virtualNetworks',
      remote 
    ))
  }
}]

var remotePeerings = flatten(map(items(config.azure.peerings),n => map(n.value, n2 => { local:n2, remote: string(n.key)})))

module PeeringRemote '../../../modules/azure/biceps/VirtualNetwork/peering.bicep' = [for network in remotePeerings: {
  name: guid(network.local,network.remote)
  scope: resourceGroup(config.azure.networks[network.local].subscription, config.azure.networks[network.local].resourceGroup)
  params: {
    networkName: network.local
    remoteNetworkIds: [resourceId(
      config.azure.networks[network.remote].subscription, 
      config.azure.networks[network.remote].resourceGroup,
      'Microsoft.Network/virtualNetworks',
      network.remote 
    )]
  }
}]

// output primaryKey string = StorageAccounts[0].outputs.primaryKey
