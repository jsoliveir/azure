targetScope = 'subscription'

param location string

param tags object = {}

resource ResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name:  deployment().name
  tags: length(items(tags)) > 0 ? tags : null
}

output tags object = tags

output name string = deployment().name

output id string = ResourceGroup.id

output location string = location
