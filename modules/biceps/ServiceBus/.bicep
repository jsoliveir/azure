targetScope = 'resourceGroup'

param tags object = resourceGroup().tags

param location string 

param queues array = []

@allowed(['Standard'])
param skuName string = 'Standard'

@allowed(['Standard'])
param skuTier string = 'Standard'

param capacity int = 1

param subnetId string 

param privateDnsZoneId string

resource ServiceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: deployment().name
  location: location
  tags: tags
  sku: {
    capacity: capacity
    name: skuName
    tier: skuTier
  }
  properties: {
    publicNetworkAccess: (skuTier == 'Premium' ? 'Disabled' : 'Enabled')
    minimumTlsVersion: '1.2'
    disableLocalAuth: false
    zoneRedundant: false
  }
}

resource RootKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-01-01-preview' = {
  parent: ServiceBus
  name: '${ServiceBus.name}-rootkey'
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}

resource RootManageSharedAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-01-01-preview' = {
  parent: ServiceBus
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

resource Queues 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = [for q in queues: {
  parent: ServiceBus
  name: q
  properties: {
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    lockDuration: 'PT1M'
    requiresDuplicateDetection: false
    enablePartitioning: false
    deadLetteringOnMessageExpiration: true
    maxMessageSizeInKilobytes: 256
    maxSizeInMegabytes: 5120
  }
}]

resource QueueAuthorizationRules 'Microsoft.ServiceBus/namespaces/queues/authorizationrules@2022-01-01-preview' = [for (q, i) in queues: {
  parent: Queues[i]
  name: q
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}]

resource NetworkRules 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-01-01-preview' = if (skuTier == 'Premium') {
  parent: ServiceBus
  name: 'default'
  properties: {
    publicNetworkAccess: 'Enabled'
    defaultAction: 'Allow'
    virtualNetworkRules: []
    ipRules: []
  }
}

resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = if (skuTier == 'Premium') {
  name: ServiceBus.name
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${ServiceBus.name}-nic'
    privateLinkServiceConnections: [
      {
        name: ServiceBus.name
        properties: {
          privateLinkServiceId: ServiceBus.id
          groupIds: [ 'namespace' ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource PrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (skuTier == 'Premium') {
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
output primaryConnectionString string = RootManageSharedAccessKey.listKeys().primaryConnectionString

