targetScope = 'resourceGroup'

param location string = resourceGroup().location

param tags object = resourceGroup().tags

param name string = deployment().name

param skuName string = 'standard'

param skuFamily string = 'A'

@secure()
param secrets object = {}

@secure()
param certificates object = {}

param softDeleteRetentionInDays int = 90

@description('''
{
  tenantId: <tenantid>
  objectId: <objectid>
  permissions: {
    certificates: [
      'all'
    ]
    keys: [
      'all'
    ]
    secrets: [
      'all'
    ]
    storage:[
      'all'
    ]
  }
}
''')
param accessPolicies array = []

resource KeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: skuFamily
      name: skuName
    }
    tenantId: tenant().tenantId
    accessPolicies: accessPolicies
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: length(accessPolicies) == 0
  }

}

resource Secrets 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = [for secret in items(secrets): {
  name: secret.key
  parent: KeyVault
  properties: {
    value: secret.value
  }
  tags: tags
}]

resource Certificates 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = [for secret in items(certificates): {
  name: secret.key
  parent: KeyVault
  properties: {
    contentType: 'application/x-pkcs12'
    value: secret.value
  }
}]

output id string = KeyVault.id

output name string = KeyVault.name
