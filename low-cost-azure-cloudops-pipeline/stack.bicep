/*
  Low-Cost CloudOps Demo
  – 1 × Standard_B1s Linux VM
  – 1 × Storage V2 account (Standard_LRS)
  – 1 × Azure SQL DB (Basic tier, single dB + logical server)
  All resources share three governance tags.
  Compile-time defaults are inexpensive and self-contained so the
  Azure DevOps pipeline can run non-interactively.
*/

@description('Deployment location')
param location string = resourceGroup().location

@description('Tag: Environment')
param environment string = 'Dev'

@description('Tag: Cost Center')
param costCenter string = 'Training'

@description('Tag: Owner')
param owner string = 'replace-with-your-name'

@description('Admin username for the Linux VM')
param adminUsername string = 'azureuser'

@description('Admin **demo** password for the Linux VM (change in real life!)')
param adminPassword string = 'P@ssword1234!'

@description('SQL server admin login')
param sqlAdminUsername string = 'sqladmin'

@description('SQL **demo** password for the SQL server (change in real life!)')
param sqlAdminPassword string = 'P@ssword1234!'

var tags = {
  Environment: environment
  CostCenter : costCenter
  Owner      : owner
}

var suffix        = uniqueString(resourceGroup().id)
var vnetName      = 'vnet-${suffix}'
var subnetName    = 'default'
var nsgName       = 'nsg-${suffix}'
var pipName       = 'pip-${suffix}'
var nicName       = 'nic-${suffix}'
var vmName        = 'b1svm'
var saName        = toLower('sa${suffix}')
var sqlServerName = 'sql${suffix}'

/* ---------- Networking ---------- */
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority              : 1000
          direction             : 'Inbound'
          access                : 'Allow'
          protocol              : 'Tcp'
          sourceAddressPrefix   : '*'
          destinationAddressPrefix: '*'
          sourcePortRange       : '*'
          destinationPortRange  : '22'
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: { publicIPAllocationMethod: 'Dynamic' }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet            : { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress   : { id: pip.id }
        }
      }
    ]
  }
}

/* ---------- Virtual machine ---------- */
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    storageProfile : {
      imageReference: {
        publisher: 'Canonical'
        offer    : '0001-com-ubuntu-server-jammy'
        sku      : '22_04-lts'
        version  : 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    osProfile: {
      computerName  : vmName
      adminUsername : adminUsername
      adminPassword : adminPassword          // demo only
      linuxConfiguration: { disablePasswordAuthentication: false }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
  }
}

/* ---------- Storage account ---------- */
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name     : saName          // must be globally unique
  location : location
  kind     : 'StorageV2'
  sku      : { name: 'Standard_LRS' }
  tags     : tags
  properties: {}
}

/* ---------- SQL logical server & basic database ---------- */
resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name     : sqlServerName
  location : location
  tags     : tags
  properties: {
    administratorLogin         : sqlAdminUsername
    administratorLoginPassword : sqlAdminPassword   // demo only
    version                    : '12.0'
    minimalTlsVersion          : '1.2'
    publicNetworkAccess        : 'Enabled'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name       : '${sqlServer.name}/maindb'
  tags       : tags
  dependsOn  : [ sqlServer ]
  properties : {
    sku: {
      name    : 'Basic'
      tier    : 'Basic'
      capacity: 5
    }
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

/* ---------- Outputs ---------- */
output vmPublicIp string = pip.properties.ipAddress
