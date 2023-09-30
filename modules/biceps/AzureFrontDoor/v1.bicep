
@allowed([ 'Standard_AzureFrontDoor' ])
param skuName string = 'Standard_AzureFrontDoor'

@description('''
```yaml
<route name>:
  endpoint: <string>
  origin: <string>
  cache: <bool>
  rulesets: <string[]>
---
route1:
  endpoint: frontend
  origin: storage
  cache: true
  rulesets:
    - headers
''')
param routes object = {}

@description('''
```yaml
<string>: <string>
---
endpoints: 
  frontend: frontend.com
''')
param endpoints object

@description('''
```yaml
<string>: 
  domain: <string>
  dnsZone: <string>
---
origins: 
  storage: 
    domain: v1.backend.com
    dnsZone: backend.com
''')
param origins object


@description('''
https://lezarn.microsoft.com/en-us/azure/templates/microsoft.cdn/profiles/rulesets/rules?pivots=deployment-language-bicep
```yaml
<string>:
  - type: <string>
    parameters: <object>
---
headers:
  - type: ModifyRequestHeader
    parameters:
      typeName: DeliveryRuleHeaderActionParameters
      headerAction: Append
      headerName: cache-control
      value: "public, max-age=86400, must-revalidate"
''')
param rulesets object

param tags object = resourceGroup().tags

@allowed([
  'IncludeSpecifiedQueryStrings'
  'IgnoreSpecifiedQueryStrings'
  'IgnoreQueryString'
  'UseQueryString'
])
param queryStringCachingBehavior string = 'UseQueryString'

@description('''
array of parameters to consider while caching endpoints
```yaml
queryStringCachingParameters:
  - param1
  - param2
''') 
param queryStringCachingParameters array = []

param ruleOrderOffset int = int(utcNow('HHmmss'))

param azureDnsZones object = {}

resource AzureFrontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: deployment().name
  tags: tags
  location: 'Global'
  sku: { name: skuName }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource AzureFrontDoorDomains 'Microsoft.Cdn/profiles/customDomains@2023-05-01' = [for ep in items(endpoints): {
  parent: AzureFrontDoor
  name: ep.key
  properties: {
    hostName: ep.value.domain
    azureDnsZone: {
      id: resourceId(
        azureDnsZones[ep.value.dnsZone].subscription,azureDnsZones[ep.value.dnsZone].resourceGroup,
        'Microsoft.Network/dnsZones',ep.value.dnsZone
      )
    }
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
}]

module DomainValidation '../PublicDnsZone/txt.bicep' =[ for (endpoint,i) in items(endpoints): {
  name: '_dnsauth.${endpoint.value.domain}'
  scope: resourceGroup(
    azureDnsZones[endpoint.value.dnsZone].subscription,
    azureDnsZones[endpoint.value.dnsZone].resourceGroup)
  params:{
    zone: endpoint.value.dnsZone
    values: [AzureFrontDoorDomains[i].properties.validationProperties.validationToken]
    name: replace('_dnsauth.${endpoint.value.domain}','.${endpoint.value.dnsZone}','')
    tags: union(tags,{ref: AzureFrontDoor.id })
    ttl: 3600
  }
}]

module DomainRecord '../PublicDnsZone/cname.bicep' =[ for (endpoint,i) in items(endpoints) : if (endpoint.value.domain != endpoint.value.dnsZone){
  name: endpoint.value.domain
  scope: resourceGroup(
    azureDnsZones[endpoint.value.dnsZone].subscription,
    azureDnsZones[endpoint.value.dnsZone].resourceGroup)
  params:{
    zone: endpoint.value.dnsZone
    value: AzureFrontDoorEndpoints[i].properties.hostName
    name: replace(endpoint.value.domain,'.${endpoint.value.dnsZone}','')
    tags: union(tags,{ref: AzureFrontDoor.id })
    ttl: 3600
  }
}]

module DomainRecordApex '../PublicDnsZone/a.bicep' =[ for (endpoint,i) in items(endpoints) : if (endpoint.value.domain == endpoint.value.dnsZone){
  name: endpoint.value.domain
  scope: resourceGroup(
    azureDnsZones[endpoint.value.dnsZone].subscription,
    azureDnsZones[endpoint.value.dnsZone].resourceGroup)
  params:{
    values: [AzureFrontDoorEndpoints[i].properties.hostName]
    targetResourceId: AzureFrontDoorEndpoints[i].id
    tags: union(tags,{ref: AzureFrontDoor.id })
    zone: endpoint.value.dnsZone
    ttl: 3600
    name: '@'
  }
}]

resource AzureFrontDoorEndpoints 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = [for ep in items(endpoints): {
  parent: AzureFrontDoor
  name: ep.key
  location: 'Global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}]

resource AzureFrontDoorOriginGroup 'Microsoft.Cdn/profiles/origingroups@2023-05-01' = [for origin in items(origins): {
  parent: AzureFrontDoor
  name: origin.key
  properties: {
    trafficRestorationTimeToHealedOrNewEndpointsInMinutes: 1
    sessionAffinityState: 'Disabled'
    loadBalancingSettings: {
      additionalLatencyInMilliseconds: 50
      successfulSamplesRequired: 3
      sampleSize: 4
    }
    healthProbeSettings:{
      probeIntervalInSeconds: 15
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probePath: '/'
    }
  }
}]

resource AzureFrontDoorOrigin 'Microsoft.Cdn/profiles/origingroups/origins@2023-05-01' = [for (origin,i) in items(origins): {
  dependsOn: [ AzureFrontDoorOriginGroup ]
  parent: AzureFrontDoorOriginGroup[i]
  name: origin.key
  properties: {
    enforceCertificateNameCheck: true
    originHostHeader: origin.value
    hostName: origin.value
    enabledState: 'Enabled'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
  }
}]

resource AzureFrontDoorRuleSet 'Microsoft.Cdn/profiles/ruleSets@2022-11-01-preview' = [for ruleset in items(rulesets): {
  parent: AzureFrontDoor
  name: ruleset.key
}]

resource AzureFrontDoorRuleSetRule 'Microsoft.Cdn/profiles/ruleSets/rules@2022-11-01-preview' = [for (rule,i) in flatten(
  map(items(rulesets),rs => map(rs.value, r => { set: rs.key, props: r}))): {
  #disable-next-line use-parent-property
  name: '${AzureFrontDoor.name}/${rule.set}/${rule.props.type}${i+1}'
  dependsOn: AzureFrontDoorRuleSet
  properties: {
    order: ruleOrderOffset + i
    conditions: rule.props.conditions
    matchProcessingBehavior: rule.props.matchProcessingBehavior
    actions: [{
      parameters: rule.props.parameters
      name: rule.props.type
    }]
  }
}]

resource AzureFrontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = [for route in items(routes): {
  #disable-next-line use-parent-property
  name: '${AzureFrontDoor.name}/${route.value.endpoint}/${route.key}'
  dependsOn: [
    AzureFrontDoorOrigin
    AzureFrontDoorRuleSet
    AzureFrontDoorDomains 
  ]
  properties: {
    customDomains: [ {
      id: resourceId('Microsoft.Cdn/profiles/customdomains',AzureFrontDoor.name,route.value.endpoint)
    }]
    originGroup: {
      id: resourceId('Microsoft.Cdn/profiles/origingroups',AzureFrontDoor.name,route.value.origin)
    }
    ruleSets: [for rule in route.value.rulesets: {
      id: resourceId('Microsoft.Cdn/profiles/rulesets',AzureFrontDoor.name,rule)
    }]
    patternsToMatch: [ '/*' ]
    supportedProtocols: [ 'Http', 'Https' ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
    cacheConfiguration: !route.value.cache ? null : {
      queryStringCachingBehavior: queryStringCachingBehavior
      queryParameters: join(queryStringCachingParameters, ',')
      compressionSettings: {
        isCompressionEnabled: true
        contentTypesToCompress: [
          'application/eot'
          'application/font'
          'application/font-sfnt'
          'application/javascript'
          'application/json'
          'application/opentype'
          'application/otf'
          'application/pkcs7-mime'
          'application/truetype'
          'application/ttf'
          'application/vnd.ms-fontobject'
          'application/xhtml+xml'
          'application/xml'
          'application/xml+rss'
          'application/x-font-opentype'
          'application/x-font-truetype'
          'application/x-font-ttf'
          'application/x-httpd-cgi'
          'application/x-javascript'
          'application/x-mpegurl'
          'application/x-opentype'
          'application/x-otf'
          'application/x-perl'
          'application/x-ttf'
          'font/eot'
          'font/ttf'
          'font/otf'
          'font/opentype'
          'image/svg+xml'
          'text/css'
          'text/csv'
          'text/html'
          'text/javascript'
          'text/js'
          'text/plain'
          'text/richtext'
          'text/tab-separated-values'
          'text/xml'
          'text/x-script'
          'text/x-component'
          'text/x-java-source'
        ]
      }
    }
  }
}]
