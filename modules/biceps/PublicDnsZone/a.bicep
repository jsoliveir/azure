
param zone string

param ttl int

param name string

param values array = []

param targetResourceId string = ''

param tags object = resourceGroup().tags

resource PublicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zone
}

resource A 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: PublicDnsZone
  name: name
  properties: {
    metadata: tags
    TTL: ttl
    targetResource: empty(targetResourceId) ? null : {
      id: targetResourceId
    }
    ARecords: [for ip in values: {
      ipv4Address: ip
    }]
  }
}

