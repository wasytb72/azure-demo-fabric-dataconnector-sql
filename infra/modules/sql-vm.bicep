@description('Location for resources')
param location string

@description('Environment name')
param environment string

@description('Subnet ID where VM will be deployed')
param subnetId string

@description('Admin username')
param adminUsername string

@secure()
@description('Admin password')
param adminPassword string

@description('VM Size')
param vmSize string = 'Standard_B2s'

@description('SQL Server version')
param sqlServerVersion string = '2022-web'

var vmName = 'sqlserver-${environment}'
var nicName = 'nic-sql-${environment}'
var osDiskName = 'osdisk-sql-${environment}'
var dataDiskName = 'datadisk-sql-${environment}'
var publicIpName = 'pip-sql-${environment}'
var nsgName = 'nsg-sql-${environment}'

// Network Security Group for SQL VM
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSQL'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowWinRM'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5985-5986'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Public IP for SQL VM
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  tags: {
    environment: environment
    role: 'sql-server'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: 'sql2022-ws2022'
        sku: 'web-gen2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          name: dataDiskName
          diskSizeGB: 128
          lun: 0
          createOption: 'Empty'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// VM Extension to configure SQL Server
resource sqlConfig 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'SqlIaasExtension'
  location: location
  properties: {
    type: 'SqlIaaSAgent'
    publisher: 'Microsoft.SqlServer.Management'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      AutoTelemetrySettings: {
        IsEnabled: true
      }
      KeyVaultCredentialSettings: {
        Enable: false
      }
    }
  }
}

@description('VM ID')
output vmId string = vm.id

@description('VM Name')
output vmName string = vm.name

@description('Public IP Address')
output publicIpAddress string = publicIp.properties.ipAddress

@description('Private IP Address')
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('SQL Server Connection String')
output sqlConnectionString string = '${publicIp.properties.ipAddress},1433'
