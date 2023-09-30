targetScope = 'resourceGroup'

param location string = resourceGroup().location

param tags object = resourceGroup().tags

param skuName string = 'Standard'

param skuFamily string = 'C'

param version string

param capacity int = 1

param subnetId string 

param privateDnsZoneId string

resource Redis 'Microsoft.Cache/redis@2022-05-01' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    redisVersion: version
    sku: {
      family: skuFamily
      capacity: capacity
      name: skuName
    }
    enableNonSslPort: true
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    redisConfiguration: {
      'maxfragmentationmemory-reserved': '125'
      'maxmemory-reserved': '125'
      'maxmemory-delta': '125'
    }
  }
}

resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: Redis.name
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${Redis.name}-nic'
    privateLinkServiceConnections: [
      {
        name: Redis.name
        properties: {
          privateLinkServiceId: Redis.id
          groupIds: [ 'redisCache' ]
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

output host string = '${Redis.properties.hostName}:${Redis.properties.sslPort}'

output port int = Redis.properties.sslPort

#disable-next-line outputs-should-not-contain-secrets
output primaryAccessKey string = Redis.listKeys().primaryKey

#disable-next-line outputs-should-not-contain-secrets
output primaryConnectionString string = '${Redis.properties.hostName}:${Redis.properties.sslPort},password=${Redis.listKeys().primaryKey},ssl=True,abortConnect=False'
