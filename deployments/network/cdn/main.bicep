targetScope = 'subscription'

var config = loadYamlContent('main.yml')

var frontDoorRuleSets = loadYamlContent('rulesets.yml')

resource ResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01'= {
  name: config.azure.resourceGroup
  location: config.azure.location
  tags: config.azure.tags
}

module FrontDoors '../../../modules/azure/biceps/AzureFrontDoor/v1.bicep' = [ for service in items(config.azure.frontDoors) :{
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  params: {
    skuName:'Standard_AzureFrontDoor'
    azureDnsZones: service.value.dnsZones
    rulesets: frontDoorRuleSets.rulesets
    endpoints: service.value.endpoints
    origins: service.value.origins
    routes: service.value.routes
  }
}]

module StorageAccounts '../../../modules/azure/biceps/StorageAccount/.bicep' =  [ for service in items(config.azure.storageAccounts) :{
  name: '${ResourceGroup.name}-${service.key}'
  scope: ResourceGroup
  params: {
    allowedIpAddresses: service.value.allowedIps
    containers: service.value.containers
    location: config.azure.location
    kind: service.value.kind
    sku: service.value.sku
  }
}]

// output primaryKey string = StorageAccounts[0].outputs.primaryKey
