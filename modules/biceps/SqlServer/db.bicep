targetScope = 'resourceGroup'

param tags object = resourceGroup().tags

param location string

@description('Sql Server name')
param serverName string

//https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql#single-database-storage-sizes-and-compute-sizes
@description('The name of the SKU, typically, a letter + Number code, e.g. P3.')
param skuName string ='Basic'

@description('The tier or edition of the particular SKU, e.g. Basic, Premium.')
@allowed(['','Basic','Standard','Premium'])
param skuTier string = ''

@description('Capacity of the particular SKU.')
param capacity int = 5

@description('Size of the particular SKU 	string')
param sizeInGb int = 2

param elasticPoolId string = ''

resource Databases 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: '${serverName}/${deployment().name}'
  location: location
  tags: tags  
  //az sql db list-editions -l northeurope -o table
  sku: {
    size: 'Basic'
    capacity: capacity
    name: skuName
    tier: skuTier
  }
  properties: {
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    requestedBackupStorageRedundancy: 'Geo'
    maxSizeBytes: (sizeInGb * 1024 * 1024 * 1024)
    elasticPoolId: elasticPoolId
    readScale: 'Disabled'
    zoneRedundant: false
    isLedgerOn: false
  }
}
