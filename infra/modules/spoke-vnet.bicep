@description('Location for resources')
param location string

@description('Environment name')
param environment string

var vnetName = 'vnet-spoke-${environment}'
var vnetAddressPrefix = '10.1.0.0/16'
var workloadSubnetPrefix = '10.1.0.0/24'
var nsgName = 'nsg-spoke-${environment}'
var lbName = 'slb-spoke-${environment}'
var lbFrontendConfigName = 'fe-private-link'
var lbBackendPoolName = 'be-private-link'
var lbPrivateIpAddress = '10.1.0.10'
var privateLinkServiceName = 'pls-sql-spoke-${environment}'
var privateLinkNatIpConfigName = 'pls-sql-nat-ipconfig'
var privateLinkNatIpAddress = '10.1.0.11'

// Network Security Group
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
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: workloadSubnetPrefix
          privateLinkServiceNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Internal Standard Load Balancer for Private Link Service
resource privateLinkLoadBalancer 'Microsoft.Network/loadBalancers@2023-11-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: lbFrontendConfigName
        properties: {
          privateIPAddress: lbPrivateIpAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/snet-workload'
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: lbBackendPoolName
      }
    ]
  }
}

// Private Link Service for SQL exposure via internal Standard Load Balancer
resource sqlPrivateLinkService 'Microsoft.Network/privateLinkServices@2023-11-01' = {
  name: privateLinkServiceName
  location: location
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: '${privateLinkLoadBalancer.id}/frontendIPConfigurations/${lbFrontendConfigName}'
      }
    ]
    ipConfigurations: [
      {
        name: privateLinkNatIpConfigName
        properties: {
          privateIPAddress: privateLinkNatIpAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/snet-workload'
          }
          primary: true
        }
      }
    ]
  }
}

@description('VNet Name')
output vnetName string = vnet.name

@description('VNet ID')
output vnetId string = vnet.id

@description('VNet Address Prefix')
output vnetAddressPrefix string = vnetAddressPrefix

@description('Workload Subnet ID')
output workloadSubnetId string = '${vnet.id}/subnets/snet-workload'

@description('Spoke Standard Load Balancer ID')
output loadBalancerId string = privateLinkLoadBalancer.id

@description('Spoke Load Balancer frontend IP configuration ID for Private Link Service')
output loadBalancerFrontendIpConfigurationId string = '${privateLinkLoadBalancer.id}/frontendIPConfigurations/${lbFrontendConfigName}'

@description('Spoke Load Balancer backend pool ID for Private Link Service backends')
output loadBalancerBackendPoolId string = '${privateLinkLoadBalancer.id}/backendAddressPools/${lbBackendPoolName}'

@description('SQL Private Link Service ID')
output sqlPrivateLinkServiceId string = sqlPrivateLinkService.id

@description('SQL Private Link Service Name')
output sqlPrivateLinkServiceName string = sqlPrivateLinkService.name
