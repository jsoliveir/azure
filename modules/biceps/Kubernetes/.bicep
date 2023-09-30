targetScope = 'resourceGroup'

param location string = resourceGroup().location

param tags object = resourceGroup().tags

param subnetId string

param dnsPrefix string

param containerRegistryId string = ''

param logsAnalyticsWorkspaceId string = ''

param dataCollectionNamespaces array = []

@description('''
```yaml
- vmSize: <string>
  version: <string>
  mode: System | User
  name: <string>
  diskSize: int
  minNodes: int
  maxNodes: int
  taints: string[]
---
nodePools:
  system:
    vmSize: Standard_B2s
    mode: System
    diskSize: 60
    taints: []
    nodes: 1
''')
param nodePools array = [ {
    vmSize: 'Standard_DS2_v2'
    version: '1.26.3'
    name: 'default'
    mode: 'System'
    diskSize: 60
    minNodes: 1
    maxNodes: 1
    taints: []
  } ]

param storageDrivers object = {
  file: false
  disk: false
  blob: false
  snapshot: false
}

var pool = first(filter(nodePools, n => n.mode == 'System'))

resource KubernetesCluster 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' = {
  name: deployment().name
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: pool.version
    nodeResourceGroup: deployment().name
    publicNetworkAccess: 'Disabled'
    dnsPrefix: dnsPrefix
    addonProfiles: {
      omsagent: {
        enabled: !empty(logsAnalyticsWorkspaceId)
        config: empty(logsAnalyticsWorkspaceId) ? {} : {
          logAnalyticsWorkspaceResourceID: logsAnalyticsWorkspaceId
          useAADAuth: 'true'
        }
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'none'
    }
    aadProfile: {
      tenantID: tenant().tenantId
      enableAzureRBAC: true
      managed: true
    }
    azureMonitorProfile: {
      metrics: {
        enabled: false
      }
    }
    identityProfile: { }
    
    agentPoolProfiles: [for pool in nodePools: {
      name: pool.name
      minCount: (pool.minNodes == pool.maxNodes) ? null : pool.minNodes
      maxCount: (pool.minNodes == pool.maxNodes) ? null : pool.maxNodes
      count: (pool.minNodes != pool.maxNodes) ? null : pool.maxNodes
      enableAutoScaling: (pool.minNodes != pool.maxNodes)
      osDiskSizeGB: pool.diskSize
      orchestratorVersion: pool.version
      vmSize: pool.vmsize
      type: 'VirtualMachineScaleSets'
      vnetSubnetID: subnetId
      scaleDownMode: 'Delete'
      kubeletDiskType: 'OS'
      osDiskType: 'Managed'
      enableEncryptionAtHost: false
      enableNodePublicIP: false
      enableUltraSSD: false
      nodeTaints: pool.taints
      enableFIPS: false
      mode: pool.mode
      osType: 'Linux'
      osSKU: 'Ubuntu'
      maxPods: 110
      tags: tags
      availabilityZones: [
        '2'
        '3'
        '1'
      ]
    }]

    servicePrincipalProfile: {
      clientId: 'msi'
    }
    enableRBAC: true
    apiServerAccessProfile: {
      enablePrivateClusterPublicFQDN: true
      enablePrivateCluster: true
      privateDNSZone: 'None'
    }
    autoScalerProfile: {
      expander: 'random'
      'scale-down-utilization-threshold': '0.5'
      'skip-nodes-with-local-storage': 'false'
      'balance-similar-node-groups': 'false'
      'scale-down-delay-after-failure': '3m'
      'scale-down-delay-after-delete': '10s'
      'max-graceful-termination-sec': '600'
      'skip-nodes-with-system-pods': 'true'
      'max-total-unready-percentage': '45'
      'scale-down-delay-after-add': '10m'
      'scale-down-unneeded-time': '10m'
      'max-node-provision-time': '15m'
      'scale-down-unready-time': '20m'
      'new-pod-scale-up-delay': '0s'
      'max-empty-bulk-delete': '10'
      'ok-total-unready-count': '3'
      'scan-interval': '10s'
    }
    // networkProfile: {
    //   loadBalancerSku: 'standard'
    //   networkPlugin: networkPlugin
    //   loadBalancerProfile: {
    //     managedOutboundIPs: {
    //       count: 1
    //     }
    //   }
    // }

    securityProfile: {
      imageCleaner: {
        intervalHours: 48
        enabled: false
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    supportPlan: 'KubernetesOfficial'
    storageProfile: {
      diskCSIDriver: {
        enabled: storageDrivers.disk
      }
      fileCSIDriver: {
        enabled: storageDrivers.file
      }
      snapshotController: {
        enabled: storageDrivers.snapshot
      }
      blobCSIDriver: {
        enabled: storageDrivers.blob
      }
    }
  }
}

resource DataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = if (!empty(dataCollectionNamespaces)) {
  location: location
  name: '${KubernetesCluster.name}-dcr-01'
  kind: 'Linux'
  tags: tags
  properties: {
    dataSources: {
      extensions:[
        {
          name: 'ContainerInsightsExtension'
          extensionName: 'ContainerInsights'
          streams: ['Microsoft-ContainerInsights-Group-Default']
          extensionSettings: {
            dataCollectionSettings : {
              enableContainerLogV2: true
              namespaceFilteringMode: 'Include'
              namespaces: dataCollectionNamespaces
              interval: '1m'
            }
          }
        } 
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'ciworkspace'
          workspaceResourceId: logsAnalyticsWorkspaceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-ContainerInsights-Group-Default'
        ]
        destinations: [
          'ciworkspace'
        ]
      }
    ]
  }
}

resource DataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = if (!empty(dataCollectionNamespaces)) {
  name: '${KubernetesCluster.name}-dcra-01'
  scope: KubernetesCluster
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this AKS Cluster.'
    dataCollectionRuleId: DataCollectionRule.id
  }
}



module CLusterRoleAssingments '../ActiveDirectory/role.rg.bicep' = {
  name: '${KubernetesCluster.name}-rbac-cluster'
  scope: resourceGroup()
  params: {    
    identity: KubernetesCluster.identity.principalId
    resourceId: KubernetesCluster.id
    roleDefinitions: {
      contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    }
  }
}

module AgentPoolRoleAssingments '../ActiveDirectory/role.rg.bicep' = {
  name: '${KubernetesCluster.name}-rbac-agent-pool'
  scope: resourceGroup()
  params: {    
    identity: KubernetesCluster.properties.identityProfile.kubeletidentity.objectId
    resourceId: KubernetesCluster.id
    roleDefinitions: {
      storageaccount_contributor: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
      keyvault_secrets_user: '4633458b-17de-408a-b874-0445c86b69e6'
      network_contributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
    }
  }
}

module ContainerRegistryRoleAssingments '../ActiveDirectory/role.rg.bicep' = if(!empty(containerRegistryId)) {
  name: '${KubernetesCluster.name}-rbac-acr'
  scope: resourceGroup()
  params: {    
    identity: KubernetesCluster.properties.identityProfile.kubeletidentity.objectId
    resourceId: containerRegistryId
    roleDefinitions: {
      acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    }
  }
}


output kubeletIdentity string = KubernetesCluster.properties.identityProfile.kubeletidentity.objectId

output identity string = KubernetesCluster.identity.principalId

output name string = KubernetesCluster.name

output id string = KubernetesCluster.id
