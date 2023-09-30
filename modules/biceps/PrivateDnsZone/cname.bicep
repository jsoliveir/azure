
param zone string

param ttl int

param name string

param value string

var tags = resourceGroup().tags

resource PrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: zone
}

resource CNAME 'Microsoft.Network/privateDnsZones/CNAME@2020-06-01' = {
  parent: PrivateDnsZone
  name: name
  properties: {
    metadata: tags
    ttl: ttl
    cnameRecord: {
      cname: value
    }
  }
}
