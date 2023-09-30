targetScope = 'resourceGroup'

param tags object = resourceGroup().tags

param zoneName string 

@description('{ ttl: int, name: string, values: string[] }')
param A array = []

@description('{ ttl: int, name: string, value: string }')
param CNAME array = []

@description('{ ttl: int, name: string, values: string[] }')
param MX array = []

@description('{ ttl: int, name: string, values: string[] }')
param TXT array = []

resource PublicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  location: 'global'
  name: zoneName
  tags: tags
}

resource CNAME_Records 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = [ for record in CNAME:{
  parent: PublicDnsZone
  name:  record.name
  properties: {
    metadata: tags
    TTL: record.ttl
    CNAMERecord: {
      cname: record.value
    }
  }
}]

resource TXT_Records 'Microsoft.Network/dnsZones/TXT@2018-05-01' = [ for record in TXT:{
  parent: PublicDnsZone
  name: record.name
  properties: {
    metadata: tags
    TTL: record.ttl
    TXTRecords: map(record.values, v => {
      value: [v]
    })
  }
}]

resource MX_Records 'Microsoft.Network/dnsZones/MX@2018-05-01' = [for record in MX:{
  parent: PublicDnsZone
  name: record.name
  properties: {
    metadata: tags
    TTL: record.ttl
    MXRecords: [for (r,i) in record.values: {
      preference: (i * 10)
      exchange: r
    }]
  }
}]

resource A_Records 'Microsoft.Network/dnsZones/A@2018-05-01' =  [for record in A:{
  parent: PublicDnsZone
  name: record.name
  properties: {
    metadata: tags
    TTL: record.ttl
    ARecords: [for ip in  record.values: {
      ipv4Address: ip
    }]
  }
}]
