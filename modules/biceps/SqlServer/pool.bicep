targetScope = 'resourceGroup'

param tags object = resourceGroup().tags

param name string = deployment().name

param capacity int

param location string

@allowed(['StandardPool'])
param sku string = 'StandardPool'

@allowed(['Standard'])
param tier string = 'Standard'

param sqlServerName string

param maxCapacityPerDatabase int

param minCapacityPerDatabase int

param maxDatabaseSizeInGb int

resource DatabasePool 'Microsoft.Sql/servers/elasticPools@2022-05-01-preview' = {
  name: '${sqlServerName}/${name}'
  location: location
  tags: tags
  sku: {
    capacity: capacity
    name: sku
    tier: tier
  }
  properties: {
    licenseType: 'BasePrice'
    maxSizeBytes:  (maxDatabaseSizeInGb * 1024 * 1024 * 1024)
    zoneRedundant: false
    perDatabaseSettings: {
      maxCapacity: maxCapacityPerDatabase
      minCapacity: minCapacityPerDatabase
    }
  }
}

output id string = DatabasePool.id
