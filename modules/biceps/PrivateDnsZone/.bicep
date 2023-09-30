targetScope = 'resourceGroup'

var tags = resourceGroup().tags

param zoneName string

@description('{ ttl: int, name: string, values: string[] }')
param A array = []

@description('{ ttl: int, name: string, value: string }')
param CNAME array = []

resource PrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  location: 'global'
  name: zoneName
  tags: tags
}

resource CNAME_Records 'Microsoft.Network/privateDnsZones/CNAME@2020-06-01' = [ for record in CNAME:{
  parent: PrivateDnsZone
  name: record.name
  properties: {
    metadata: tags
    ttl: record.ttl
    cnameRecord: {
      cname: record.value
    }
  }
}]

resource A_Records 'Microsoft.Network/privateDnsZones/A@2020-06-01' =  [for record in A:{
  parent: PrivateDnsZone
  name: record.name
  properties: {
    metadata: tags
    ttl: record.ttl
    aRecords: [for ip in record.values: {
      ipv4Address: ip
    }]
  }
}]
