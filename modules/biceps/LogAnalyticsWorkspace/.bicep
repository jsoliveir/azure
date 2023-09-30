param name string = deployment().name

param location string = resourceGroup().location

resource LogsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name:  name
}

output id string = LogsWorkspace.id

output name string = LogsWorkspace.name
