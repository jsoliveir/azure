targetScope = 'resourceGroup'

var config = loadYamlContent('../modules.yaml')

param location string = resourceGroup().location

param tags object = resourceGroup().tags

@allowed(['Free','Standard'])
param sku string = 'Free'

param enterpriseGrade bool = false

param publicNetworkAccess bool = true

param subnetId string = ''

@description('''
<domain>.<dns-zone>:
  resourceGroup: <string>
  subscriptionId: <string>
''')
param customDomains object

resource WebApplication 'Microsoft.Web/staticSites@2022-09-01' = {
  name: deployment().name
  location: location
  tags: union(tags, {
    domain: items(customDomains)[0].key
  })
  sku:{
    tier: sku
    name: sku
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    enterpriseGradeCdnStatus: enterpriseGrade ? 'Enabled' : 'Disabled'
  }

  resource CustomDomain 'customDomains' = [ for domain in items(customDomains) :{
    dependsOn: CNAME
    name: domain.key
    properties: {
      validationMethod: 'cname-delegation'
    }
  }]
}

module CNAME '../PublicDnsZone/cname.bicep' =[ for domain in items(customDomains) :{
  name: domain.key
  scope: resourceGroup(domain.value.subscriptionId,domain.value.resourceGroup)
  params:{
    zone: replace(domain.key,'${first(split(domain.key,'.'))}.','')
    value: WebApplication.properties.defaultHostname
    name: first(split(domain.key,'.'))
    ttl: 3600
  }
}]

resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = if (!empty(subnetId)) {
  name: WebApplication.name
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${WebApplication.name}-nic'
    privateLinkServiceConnections: [
      {
        name: WebApplication.name
        properties: {
          privateLinkServiceId: WebApplication.id
          groupIds: [ 'staticSites' ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource PrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = if (!empty(subnetId)) {
  name:  WebApplication.name
  parent: PrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: resourceId(
            config.network.subscription,config.network.dnszones.resourceGroup,
            'Microsoft.Network/privateDnsZones',
            #disable-next-line no-hardcoded-env-urls
            'privatelink.azurestaticapps.net'
          )
        }
      }
    ]
  }
}
