
param zone string

param ttl int

param name string

param value string = ''

param targetResourceId string = ''

param tags object = resourceGroup().tags

resource PublicDnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: zone
}

resource CNAME 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: PublicDnsZone
  name: name
  properties: {
    metadata: tags
    TTL: ttl
    targetResource: empty(targetResourceId) ? null : {
      id: targetResourceId
    }
    CNAMERecord: empty(value) ? null : {
      cname: value
    }
  }
}
