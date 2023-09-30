
param zone string

param ttl int

param name string

param values array

param tags object = resourceGroup().tags

resource PublicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zone
}

resource TXT 'Microsoft.Network/dnsZones/TXT@2018-05-01' =  {
  parent: PublicDnsZone
  name: name
  properties: {
    metadata: tags
    TTL: ttl
    TXTRecords: map(values, v => {
      value: [v]
    })
  }
}
