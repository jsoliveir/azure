param location string = resourceGroup().location

param tags object = resourceGroup().tags

param subnetId string

param publicIp bool = true

param dataDiskSize int = 50

param privateIp string

@description('plain text script data')
param provisioningScripts array = []

param vmSize string = 'Standard_B2s'

param osDiskSku string = 'Standard_LRS'

param adminUser string = deployment().name

param enableIpForwading bool = false

@secure()
#disable-next-line secure-parameter-default
param adminPassword string = guid(utcNow('yyyyMMddhhmmss'))

// param dataDiskSku string = 'Standard_LRS'

// resource DataDisk 'Microsoft.Compute/disks@2022-07-02' = {
//   name: deployment().name
//   location: location
//   sku: {
//     name: 'dataDiskSku'
//   }
//   tags: tags
//   properties: {
//     diskSizeGB: dataDiskSize
//     publicNetworkAccess: 'Disabled'
//     creationData:{
//       createOption: 'Empty'
//     }
//   }
// }

resource PublicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = if(publicIp) {
  name: deployment().name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    dnsSettings: {
      domainNameLabel: deployment().name
    }
    publicIPAllocationMethod: 'Static'
    
  }
}

resource NetworkInterface 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    enableIPForwarding: enableIpForwading
    ipConfigurations: [
      { 
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddress: privateIp
          primary: true
          publicIPAddress: {
            id: PublicIp.id
            properties: {
              dnsSettings: {
                domainNameLabel: deployment().name
              }
            }
          }   
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource VirtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'hostname'
      adminPassword: adminPassword
      adminUsername: adminUser
    }
    storageProfile: {
      imageReference: {
        offer: '0001-com-ubuntu-server-focal'
        publisher: 'Canonical'
        version: 'latest'
        sku: '20_04-lts'
      }
      osDisk: {
        name: deployment().name
        diskSizeGB: dataDiskSize
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: osDiskSku
        }
      }
      // dataDisks: [
      //   {
      //     createOption: 'Attach'
      //     managedDisk: {
      //       id: DataDisk.id
      //     }
      //     lun: 0
      //   }
      // ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: NetworkInterface.id
          properties:{
            primary: true
          }
        }
      ]
    }
  }
}

resource ProvisioningScript 'Microsoft.Compute/virtualMachines/runCommands@2023-07-01' = if(length(provisioningScripts) > 0){
  parent: VirtualMachine
  name: 'RunShellScript'
  location: location
  tags: tags
  properties:{
    source: {
      script: join(provisioningScripts,'\n')
    }
  }
}
