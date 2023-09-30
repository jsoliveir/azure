targetScope = 'resourceGroup'

var config = loadYamlContent('../modules.yaml')

param location string = resourceGroup().location

param tags object = resourceGroup().tags

param allowedIpAddresses array = []

param allowedSubnetsIds array = [ ]

param softDeleteRetentionDays int = 7

param softDeleteEnabled bool = false

param nfs bool = false

param adls bool = false

@allowed([
  'Standard_RAGZRS'
  'Standard_LRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param sku string = 'Standard_LRS'

@allowed(['BlockBlobStorage','FileStorage','StorageV2','Storage'])
param kind string = 'StorageV2'

@allowed(['Hot','Cool'])
param accessTier string = 'Hot'

param subnetId string = ''

@description('array of { name: <string>, size: <int> }')
param shares array = []

@description('''
A list of container names. 
Annotate the name with ::public (eg. name::public) if you want to get the container publicly available
''')
param containers array = []

var publicAccess = length(subnetId) == 0 && length(allowedIpAddresses) == 0

var networkRules = [for id in allowedSubnetsIds: {
  action: 'Allow'
  id: id
}]

var ipRules = [for ip in allowedIpAddresses: {
  action: 'Allow'
  value: ip
}]

var specialChars = [ '-', '_', '.' ]

resource StorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: join(split(deployment().name, specialChars), '')
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    allowBlobPublicAccess: publicAccess
    allowCrossTenantReplication: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
    isNfsV3Enabled: nfs
    isHnsEnabled: adls
    accessTier: accessTier
    networkAcls: {
      defaultAction: publicAccess ? 'Allow' : 'Deny'
      virtualNetworkRules: networkRules
      bypass: 'AzureServices'
      ipRules: ipRules
    }
  }

  resource BlobServices 'blobServices' = if(length(containers) > 0) {
    name: 'default'
    properties:{
      deleteRetentionPolicy: {
        enabled: softDeleteEnabled
        days: softDeleteRetentionDays 
      }
      containerDeleteRetentionPolicy: {
        days: softDeleteRetentionDays
        enabled: softDeleteEnabled
      }
    }
    resource Containers 'containers' = [for container in containers: {
      name: first(split(container,':'))
      properties:{
        publicAccess: contains(container,':public') ? 'Container' : 'None'
      }
    }]
  }
  
  resource FileService 'fileServices' = if(length(shares) > 0) {
    name: 'default'
    properties:{
      shareDeleteRetentionPolicy:{
        days: softDeleteRetentionDays
        enabled: softDeleteEnabled
      }
    }
    resource Shares 'shares' = [for share in shares: {
      name: share.name
      
      properties:{
        shareQuota: share.size
        accessTier: 'TransactionOptimized'
      }
    }]
  }
}

resource FilePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = if(!publicAccess && !empty(shares)) {
  name: '${StorageAccount.name}file'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${StorageAccount.name}filenic'
    privateLinkServiceConnections: [
      {
        name: StorageAccount.name
        properties: {
          privateLinkServiceId: StorageAccount.id
          groupIds: [ 'file' ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource FilePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if(!publicAccess && !empty(shares)) {
  name: '${StorageAccount.name}file'
  parent: FilePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: resourceId(
            config.network.subscription,config.network.dnszones.resourceGroup,
            'Microsoft.Network/privateDnsZones',
            #disable-next-line no-hardcoded-env-urls
            'privatelink.file.core.windows.net'
          )
        }
      }
    ]
  }
}

resource BlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = if(!publicAccess && !empty(containers)) {
  name: '${StorageAccount.name}blob'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${StorageAccount.name}blobnic'
    privateLinkServiceConnections: [
      {
        name: StorageAccount.name
        properties: {
          privateLinkServiceId: StorageAccount.id
          groupIds: [ 'blob' ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource BlobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if(!publicAccess && !empty(containers)) {
  name: '${StorageAccount.name}blob'
  parent: BlobPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: resourceId(
            config.network.subscription,config.network.dnszones.resourceGroup,
            'Microsoft.Network/privateDnsZones',
            #disable-next-line no-hardcoded-env-urls
            'privatelink.blob.core.windows.net'
          )
        }
      }
    ]
  }
}


#disable-next-line outputs-should-not-contain-secrets
output primaryKey string = StorageAccount.listKeys().keys[0].value

#disable-next-line outputs-should-not-contain-secrets
output primaryConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

output apiVersion string = StorageAccount.apiVersion

output name string = StorageAccount.name

output id string = StorageAccount.id
