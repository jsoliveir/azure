targetScope = 'subscription'

@allowed([ 'development', 'production' ])
param environment string

var environments = {
  development: loadYamlContent('development.yml')
  production: loadYamlContent('production.yml')
}

var dns = loadYamlContent('../../network/dns/main.yml')

var config = environments[environment]

var privateDnsZones = [ 'tools.habitushealth.net' ]

var containerRegistryId = resourceId(
  'c8c63fd1-88d1-4d34-bfdd-632fbe12e963', 'habitus-devops-eu',
  'Microsoft.ContainerRegistry/registries',
  'HabitusHealthEU01'
)

resource ResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: config.azure.resourceGroup
  location: config.azure.location
  tags: config.azure.tags
}

module VirtualNetwork '../../../modules/azure/biceps/VirtualNetwork/.bicep' = [for network in items(config.azure.networks): {
  name: '${ResourceGroup.name}-${network.key}'
  scope: ResourceGroup
  params: {
    location: network.value.location
    subnets: network.value.subnets
    serviceEndpoints: network.value.serviceEndpoints
    privateDnsZoneIds: map(privateDnsZones, pdnsz => resourceId(
      dns.azure.subscription, dns.azure.resourceGroup,
      'Microsoft.Network/privateDnsZones', pdnsz
    ))
  }
}]

module Kubernetes '../../../modules/azure/biceps/Kubernetes/.bicep' = [for service in items(config.azure.kubernetes): {
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  dependsOn: VirtualNetwork
  params: {
    dnsPrefix: replace(service.key, '-', '')
    storageDrivers: service.value.storageDrivers
    location: config.azure.networks[service.value.network].location
    containerRegistryId: containerRegistryId
    subnetId: resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${service.value.network}',
      '${service.value.subnet}'
    )
    nodePools: map(items(service.value.nodePools), node => {
        version: service.value.version
        diskSize: node.value.diskSize
        minNodes: node.value.nodes
        maxNodes: node.value.nodes
        taints: node.value.taints
        vmSize: node.value.vmSize
        mode: node.value.mode
        name: node.key
      })
  }
}]


module SignalR '../../../modules/azure/biceps/SignalR/.bicep' = [for service in items(config.azure.signalr): {
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  dependsOn: VirtualNetwork
  params:{
    location: config.azure.networks[service.value.network].location
    clientEndpoint: service.value.entrypoint
    capacity: service.value.capacity
    skuName: service.value.sku
    subnetId: resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${service.value.network}',
      '${service.value.subnet}'
    )
    privateDnsZoneId: resourceId(
      dns.azure.subscription, dns.azure.resourceGroup,
      'Microsoft.Network/privateDnsZones',
      'privatelink.service.signalr.net'
    )
  }
}]

module ServiceBus '../../../modules/azure/biceps/ServiceBus/.bicep' = [for service in items(config.azure.servicebus): {
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  dependsOn: VirtualNetwork
  params: {
    location: config.azure.networks[service.value.network].location
    capacity: service.value.capacity
    queues: service.value.queues
    skuTier: service.value.sku
    skuName: service.value.sku
    subnetId: resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${service.value.network}',
      '${service.value.subnet}'
    )
    privateDnsZoneId: resourceId(
      dns.azure.subscription, dns.azure.resourceGroup,
      'Microsoft.Network/privateDnsZones',
      'privatelink.servicebus.windows.net'
    )
  }
}]

module RedisCache '../../../modules/azure/biceps/RedisCache/.bicep' = [for service in items(config.azure.redis): {
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  dependsOn: VirtualNetwork
  params: {
    capacity: service.value.capacity
    skuFamily: service.value.family
    skuName: service.value.sku
    location: config.azure.networks[service.value.network].location  
    version: string(service.value.version)
    subnetId: resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${service.value.network}',
      '${service.value.subnet}'
    )
    privateDnsZoneId: resourceId(
      dns.azure.subscription, dns.azure.resourceGroup,
      'Microsoft.Network/privateDnsZones',
      'privatelink.redis.cache.windows.net'
    )
  }
}]

module StorageAccounts '../../../modules/azure/biceps/StorageAccount/.bicep' =  [ for service in items(config.azure.storageAccounts) :{
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  dependsOn: VirtualNetwork
  params: {
    location: config.azure.networks[service.value.network].location
    kind: service.value.kind
    sku: service.value.sku
    shares: service.value.shares
    containers: service.value.containers
    adls: service.value.asdl
    nfs: service.value.nfsv3
    softDeleteRetentionDays: 7
    softDeleteEnabled: true
    subnetId: resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${service.value.network}',
      '${service.value.subnet}')
  }
}]

module MicrosoftSQL '../../../modules/azure/biceps/SqlServer/.bicep' = [ for service in items(config.azure.mssql.servers) :{
  scope: ResourceGroup
  name: '${ResourceGroup.name}-${service.key}'
  dependsOn: VirtualNetwork
  params:{
    location: config.azure.networks[service.value.network].location
    adminGroup: config.azure.mssql.adminGroup
    subnetId: resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Network/virtualNetworks/subnets',
      '${ResourceGroup.name}-${service.value.network}',
      '${service.value.subnet}')
    privateDnsZoneId: resourceId(
      dns.azure.subscription, dns.azure.resourceGroup,
      'Microsoft.Network/privateDnsZones',
      #disable-next-line no-hardcoded-env-urls
      'privatelink.database.windows.net'
    )
  }
}]

module MicrosoftSQLElasticPool '../../../modules/azure/biceps/SqlServer/pool.bicep' =  [ for pool in items(config.azure.mssql.databasePools) :{ 
  dependsOn: MicrosoftSQL
  scope: ResourceGroup
  name: 'elastic-pool-${pool.value.server}-${pool.key}'
  params:{
    name: pool.key
    location: config.azure.networks[config.azure.mssql.servers[pool.value.server].network].location
    capacity: pool.value.capacity
    maxCapacityPerDatabase: pool.value.maxCapacityPerDatabase
    minCapacityPerDatabase: pool.value.minCapacityPerDatabase
    maxDatabaseSizeInGb: pool.value.maxDatabaseSize
    sqlServerName: '${ResourceGroup.name}-${pool.value.server}'
  }
}]

module MicrosoftSQLDatabase '../../../modules/azure/biceps/SqlServer/db.bicep' =  [ for db in items(config.azure.mssql.databases) :{ 
  dependsOn: MicrosoftSQLElasticPool
  scope: ResourceGroup
  name: db.key
  params:{
    location: config.azure.networks[config.azure.mssql.servers[db.value.server].network].location
    serverName: '${ResourceGroup.name}-${db.value.server}'
    capacity: db.value.capacity
    sizeInGb: db.value.size
    skuName: db.value.sku
    skuTier: db.value.tier
    elasticPoolId: empty(db.value.pool) || db.value.sku != 'ElasticPool'  ? '' : resourceId(
      subscription().subscriptionId, ResourceGroup.name,
      'Microsoft.Sql/servers/elasticPools',
      '${ResourceGroup.name}-${db.value.server}',
      '${db.value.pool}'
    )
  }
}]

module KeyVault '../../../modules/azure/biceps/KeyVault/.bicep' = {
  name: '${ResourceGroup.name}-akv-01'
  scope: ResourceGroup
  params: {
    name: ResourceGroup.name
    softDeleteRetentionInDays: config.azure.keyvault.softDeleteRetentionInDays
    location: config.azure.location
  }
}

module ServiceBusKeyVaultSecret '../../../modules/azure/biceps/KeyVault/secret.bicep' = [for (_,i) in items(config.azure.signalr): {
  name: 'secret-${ServiceBus[i].name}--cstr'
  scope: ResourceGroup
  params:{
    keyVaultName: KeyVault.outputs.name
    secretName: '${ServiceBus[i].name}--cstr'
    value: ServiceBus[i].outputs.primaryConnectionString
  }
}]

module RedisCacheSecret '../../../modules/azure/biceps/KeyVault/secret.bicep' = [for (_,i) in items(config.azure.redis): {
  name: 'secret-${RedisCache[i].name}--cstr'
  scope: ResourceGroup
  params:{
    keyVaultName: KeyVault.outputs.name
    secretName: '${RedisCache[i].name}--cstr'
    value: RedisCache[i].outputs.primaryConnectionString
  }
}]

module RedisCacheHostSecret '../../../modules/azure/biceps/KeyVault/secret.bicep' = [for (_,i) in items(config.azure.redis): {
  name: 'secret-${RedisCache[i].name}--host'
  scope: ResourceGroup
  params:{
    keyVaultName: KeyVault.outputs.name
    secretName: '${RedisCache[i].name}--host'
    value: RedisCache[i].outputs.host
  }
}]

module RedisCacheAccessKeySecret '../../../modules/azure/biceps/KeyVault/secret.bicep' = [for (_,i) in items(config.azure.redis): {
  name: 'secret-${RedisCache[i].name}--key'
  scope: ResourceGroup
  params:{
    keyVaultName: KeyVault.outputs.name
    secretName: '${RedisCache[i].name}--key'
    value: RedisCache[i].outputs.primaryAccessKey
  }
}]

module SigalRSecret '../../../modules/azure/biceps/KeyVault/secret.bicep' = [for (_,i) in items(config.azure.signalr): {
  name: 'secret-${SignalR[i].name}--cstr'
  scope: ResourceGroup
  params:{
    keyVaultName: KeyVault.outputs.name
    secretName: '${SignalR[i].name}--cstr'
    value: SignalR[i].outputs.primaryConnectionString
  }
}]

module StorageAccountSecret '../../../modules/azure/biceps/KeyVault/secret.bicep' = [for (_,i) in items(config.azure.storageAccounts): {
  name: 'secret-${StorageAccounts[i].name}--cstr'
  scope: ResourceGroup
  params:{
    keyVaultName: KeyVault.outputs.name
    secretName: '${StorageAccounts[i].outputs.name}--cstr'
    value: StorageAccounts[i].outputs.primaryConnectionString
  }
}]
