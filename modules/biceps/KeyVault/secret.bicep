param keyVaultName string = resourceGroup().name

param secretName string = deployment().name

param tags object = resourceGroup().tags

@secure()
param value string

resource KeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource Secrets 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: secretName
  parent: KeyVault
  tags: tags
  properties: {
    value: value
  }
}
