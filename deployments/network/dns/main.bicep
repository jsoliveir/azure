targetScope = 'subscription'

var config = loadYamlContent('main.yml')

resource ResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: config.azure.resourceGroup
  location: config.azure.location
  tags: config.azure.tags
}

module PrivateDnsZones '../../../modules/azure/biceps/PrivateDnsZone/.bicep' = [for pdns in items(config.azure.privateDnsZones) : {
  scope: ResourceGroup
  name: contains(config.azure.publicDnsZones,pdns.key) ? 'privatelink.${pdns.key}' : pdns.key
  params: {
    zoneName: pdns.key
    CNAME: filter(pdns.value, d => d.type == 'CNAME')
    A: filter(pdns.value, d => d.type == 'A')
  }
}]

module PublicDnsZones '../../../modules/azure/biceps/PublicDnsZone/.bicep' = [for dns in items(config.azure.publicDnsZones) : {
  scope: ResourceGroup
  name: dns.key
  params: {
    zoneName: dns.key
    CNAME: filter(dns.value, d => d.type == 'CNAME')
    TXT: filter(dns.value, d => d.type == 'TXT')
    MX: filter(dns.value, d => d.type == 'MX')
    A: filter(dns.value, d => d.type == 'A')
  }
}]
