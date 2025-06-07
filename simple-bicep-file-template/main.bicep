param location string = resourceGroup().location
param vmSize  string = 'Standard_B1s'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'demoVNet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: 'default'
        properties: { addressPrefix: '10.0.0.0/24' }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'demoNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource myVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'demoVm'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'demoVm'
      adminUsername: 'cloudlearner'
      adminPassword: 'TestPassword123!'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
  }
}
