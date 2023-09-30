
param zone string

param ttl int

param name string

param values array

var tags = resourceGroup().tags

resource PublicDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: zone
}

resource A 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: PublicDnsZone
  name: name
  properties: {
    metadata: tags
    ttl: ttl
    aRecords: [for ip in values: {
      ipv4Address: ip
    }]
  }
}

