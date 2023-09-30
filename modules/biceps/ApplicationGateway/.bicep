targetScope = 'resourceGroup'

param location string = resourceGroup().location

param tags object = resourceGroup().tags

param capacity int = 1

param subnetId string

param privateIpAddress string

@description('''a map of object 
'domain': {
  public: 'bool'
  certificate: 'string'
  protocol: 'Https|Http'
  backend_protocol: 'Https|Http'
  backend_pool: []
}''')
param listeners object

param certificates array

@allowed([ 'WAF', 'Standard' ])
param gatewayType string = 'Standard'

@allowed([ 'Detection', 'Prevention' ])
param firewallMode string = 'Detection'

var sku = {
  WAF: {
    name: 'WAF_V2'
    tier: 'WAF_V2'
  }
  Standard: {
    name: 'Standard_v2'
    tier: 'Standard_v2'
  }
}

@description('''
https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-configuration?tabs=bicep#waf-exclusion-lists
{
  matchVariable: 'RequestArgNames'
  selectorMatchOperator: 'StartsWith'
  selector: 'user'
}
''')
param firewallExclusions array = []

resource PublicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: deployment().name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: deployment().name
    }
  }
}

resource Identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: deployment().name 
  location: location
  tags: tags
}

module RoleAssingments '../ActiveDirectory/role.rg.bicep' = {
  name: '${Identity.name}-rbac'
  scope: resourceGroup()
  params: {    
    identity: Identity.properties.principalId
    resourceId: Identity.id
    roleDefinitions: {
      keyvault_secrets_user: '4633458b-17de-408a-b874-0445c86b69e6'
    }
  }
}

resource Gateway 'Microsoft.Network/applicationGateways@2022-05-01' = {
  name: deployment().name
  dependsOn: [RoleAssingments]
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${Identity.id}': {}
    } 
  }
  properties: {
    sku: {
      capacity: capacity
      name: sku[gatewayType].name
      tier: sku[gatewayType].name
    }
    gatewayIPConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    sslCertificates: [for cert in certificates: {
      name: cert.name
      properties: {
        keyVaultSecretId: contains(cert,'keyVaultSecretId') ? cert.keyVaultSecretId : null
        password: contains(cert,'password') ? cert.password : null
        data: contains(cert,'data') ? cert.data : null
      }
    }]
    frontendIPConfigurations: [
      {
        name: 'public'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PublicIp.id
          }
        }
      }
      {
        name: 'private'
        properties: {
          privateIPAddress: privateIpAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'http'
        properties: {
          port: 80
        }
      }
      {
        name: 'https'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [for c in items(listeners): {
      name: c.key
      properties: {
        backendAddresses: map(c.value.backend_pool, p => {
            fqdn: p
          })
      }
    }]
    backendHttpSettingsCollection: [
      {
        name: 'http'
        properties: {
          port: 80
          protocol: 'Http'
          pickHostNameFromBackendAddress: true
          requestTimeout: 120
          path: '/'
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', deployment().name, 'http')
          }
        }
      }
      {
        name: 'https'
        properties: {
          port: 443
          protocol: 'Https'
          requestTimeout: 120
          pickHostNameFromBackendAddress: true
          path: '/'
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', deployment().name, 'https')
          }
        }
      }
    ]
    httpListeners: [for c in items(listeners): {
      name: c.key
      properties: {
        hostName: c.key
        protocol: c.value.protocol
        frontendIPConfiguration: {
          id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', deployment().name, toLower(c.value.public ? 'public' : 'private'))
        }
        frontendPort: {
          id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', deployment().name, toLower(c.value.protocol))
        }
        sslCertificate: {
          id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', deployment().name, c.value.certificate)
        }
        requireServerNameIndication: false
      }
    }]
    requestRoutingRules: [for (c, i) in items(listeners): {
      name: c.key
      properties: {
        ruleType: 'Basic'
        priority: (i + 1) * 100
        httpListener: {
          id: resourceId('Microsoft.Network/applicationGateways/httpListeners', deployment().name, c.key)
        }
        backendAddressPool: {
          id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', deployment().name, c.key)
        }
        backendHttpSettings: {
          id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', deployment().name, toLower(c.value.backend_protocol))
        }
      }
    }]
    probes: [
      {
        name: 'Https'
        properties: {
          protocol: 'Https'
          path: '/healthz'
          interval: 15
          timeout: 60
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-404'
            ]
          }
        }
      }
      {
        name: 'Http'
        properties: {
          protocol: 'Http'
          path: '/healthz'
          interval: 15
          timeout: 60
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-404'
            ]
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: gatewayType != 'WAF' ? null : {
      firewallMode: firewallMode
      ruleSetVersion: '3.2'
      ruleSetType: 'OWASP'
      enabled: true
      exclusions: map(firewallExclusions, e => {
        matchVariable: e.matchVariable 
        selectorMatchOperator: e.selectorMatchOperator
        selector: e.selector
      })
    } 
  }
}

output publicIpAddress string = PublicIp.properties.ipAddress

output privateIpAddress string = privateIpAddress
