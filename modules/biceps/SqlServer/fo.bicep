targetScope = 'resourceGroup'

param tags object = resourceGroup().tags

param primary string

param partners array

param databases array

resource SqlFailOverGroup 'Microsoft.Sql/servers/failoverGroups@2021-11-01' = {
  name: '${primary}/${deployment().name}'
  tags: tags
  properties: {
    readOnlyEndpoint: {
      failoverPolicy: 'Enabled'
    }
    readWriteEndpoint: {
      failoverPolicy: 'Automatic'
      failoverWithDataLossGracePeriodMinutes: 60
    }
    databases: [for name in databases: resourceId(
      'Microsoft.Sql/servers/databases',
      primary, name)]
    partnerServers: [for partner in partners: {
      id: resourceId('Microsoft.Sql/servers', partner)
    }]
  }
}
