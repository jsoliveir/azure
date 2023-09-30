targetScope = 'subscription'

var config = loadYamlContent('main.yml')

var dns = loadYamlContent('../dns/main.yml')

var privateDnsZones =  map(items(dns.azure.privateDnsZones),d => d.key)

resource ResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: config.azure.resourceGroup
  location: config.azure.location
  tags: config.azure.tags
}

module KeyVault '../../../modules/azure/biceps/KeyVault/.bicep' = {
  name: ResourceGroup.name
  scope: ResourceGroup
  params: {
    location: config.azure.location
    softDeleteRetentionInDays: 7
  }
}

module VirtualNetwork '../../../modules/azure/biceps/VirtualNetwork/.bicep' = [for network in items(config.azure.networks) :{
  name: '${ResourceGroup.name}-${network.key}'
  scope: ResourceGroup
  params: {
    location: network.value.location
    subnets: network.value.subnets
    serviceEndpoints: network.value.serviceEndpoints
    subnetDelegations: network.value.subnetDelegations
    securityRules: network.value.securityRules
    privateDnsZoneIds: map(privateDnsZones,pdnsz => resourceId(
      subscription().subscriptionId,'habitus-dns',
      'Microsoft.Network/privateDnsZones', pdnsz
    ))
  }
}]

module ContainerInstances '../../../modules/azure/biceps/ContainerInstance/.bicep' =  [for container in items(config.azure.containers) :{
  name: '${ResourceGroup.name}-${container.key}'
  dependsOn: VirtualNetwork
  scope: ResourceGroup
  params: {
    cpu: string(container.value.cpu)
    mem: string(container.value.mem)
    image: container.value.image 
    location: config.azure.networks[container.value.network].location
    environment: container.value.environment
    subnetId: resourceId(
      subscription().subscriptionId,ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${container.value.network}',
      '${container.value.subnet}'
    )
  }
}]

module ApplicationGateways '../../../modules/azure/biceps/ApplicationGateway/.bicep' = [for gw in items(config.azure.gateways) :{
  name: '${ResourceGroup.name}-${gw.key}'
  dependsOn: VirtualNetwork
  scope: ResourceGroup
  params: {
    location: config.azure.networks[gw.value.network].location
    certificates: map(items(gw.value.certificates), c=> {
      name: c.key
      keyVaultSecretId: 'https://${ResourceGroup.name}${environment().suffixes.keyvaultDns}/secrets/${c.value.secretName}'
    })
    listeners: gw.value.listeners
    privateIpAddress: gw.value.privateIp
    capacity: gw.value.capcity
    gatewayType: 'Standard'
    subnetId: resourceId(
      subscription().subscriptionId,ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${gw.value.network}',
      '${gw.value.subnet}'
    )
  }
}]


module VirtualMachines '../../../modules/azure/biceps/VirtualMachine/.bicep' =  [for vm in items(config.azure.virtualMachines) :{
  name: '${ResourceGroup.name}-${vm.key}'
  dependsOn: VirtualNetwork
  scope: ResourceGroup
  params: {
    location: config.azure.networks[vm.value.network].location
    privateIp: vm.value.privateIp
    enableIpForwading: vm.value.ipForwading
    // provisioningScripts: map(vm.value.scripts,s => loadTextContent(s))
    publicIp: vm.value.publicIp
    vmSize: vm.value.vmSize
    subnetId:  resourceId(
      subscription().subscriptionId,ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${vm.value.network}',
      '${vm.value.subnet}'
    )
  }
}]
