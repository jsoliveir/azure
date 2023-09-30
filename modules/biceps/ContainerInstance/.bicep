param location string = resourceGroup().location

param tags object = resourceGroup().tags

param name string = deployment().name

param image string

@description('[{number: 80, proto: TCP|UDP}]')
param ports array = [{
  number: 65534
  proto: 'UDP'
}]

param cpu string = '0.5'

param mem string = '0.5'

param ipAddress string = ''

param restartPolicy string = 'Always'

@allowed([ 'Linux', 'Windows' ])
param osType string = 'Linux'

param subnetId string = ''

param environment object = {}

param command array = []

@description('''Array of {
  shareName: string
  mountPath: string
  storageAccountName: string
  storageAccountKey: string
}''')
param volumes array = []

@description('''Array of {
  repository: string
  directory: string
  revision: string
}''')
param gitRepos array = []

resource ContainerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    osType: osType
    restartPolicy: restartPolicy
    ipAddress: {
      type: empty(subnetId) ? 'Public' : 'Private'
      dnsNameLabel: empty(subnetId) ? name : null
      ports: [for port in ports: {
        protocol: port.proto
        port: port.number
      }]
      ip: ipAddress
    }
    subnetIds: empty(subnetId) ? [] : [ {
        id: subnetId
      } ]
    volumes: union(
      map(volumes, v => {
          name: v.shareName
          azureFile: {
            shareName: v.shareName
            storageAccountName: v.storageAccountName
            storageAccountKey: v.storageAccountKey
          }
        }),
      map(gitRepos, git => {
          name: git.repository
          gitRepo: {
            repository: git.repository
            directory: git.directory
            revision: git.revision
          }
        })
    )
    containers: [ {
        name: name
        properties: {
          image: image
          command: command
          ports: [for port in ports: {
            protocol: port.proto
            port: port.number
          }]
          volumeMounts: map(volumes, v => {
              mountPath: v.mountPath
              name: v.shareName
            }
          )
          environmentVariables: [for env in items(environment): {
            secureValue: env.value.secret ? env.value.value : null
            value: !env.value.secret ? env.value.value : null
            name: env.key
          }]
          resources: {
            requests: {
              cpu: json(cpu)
              memoryInGB: json(mem)
            }
          }
        }
      }
    ]
  }
}

output ipAddress string = ContainerGroup.properties.ipAddress.ip

output id string = ContainerGroup.id
