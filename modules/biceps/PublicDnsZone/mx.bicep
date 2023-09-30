
param zone string

param ttl int

param name string

param values array

param tags object = resourceGroup().tags

resource PublicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zone
}

resource MX 'Microsoft.Network/dnsZones/MX@2018-05-01' = {
  parent: PublicDnsZone
  name: name
  properties: {
    metadata: tags
    TTL: ttl
    MXRecords: [for (r,i) in values: {
      preference: (i * 10)
      exchange: r
    }]
  }
}
