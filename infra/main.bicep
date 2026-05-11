targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the resource group')
param resourceGroupName string = 'rg-landing-zone-demo'

@description('Azure region for deployment')
param location string = 'eastus'

@description('Environment name')
param environment string = 'demo'

@description('Admin username for Windows VM')
param adminUsername string = 'demoadmin'

@secure()
@description('Admin password for Windows VM')
param adminPassword string

@description('SQL Server version')
param sqlServerVersion string = '2022-web'

@description('Deployment timestamp used for resource tagging')
param deploymentTimestamp string = utcNow('u')

@description('Name for the Azure Fabric Capacity to be created. Must be globally unique.')
param fabricCapacityName string = 'repfabcap${environment}'

@description('Name for the Azure Fabric Workspace to be created. Must be globally unique.')
param workspaceName string = 'repfabwks${environment}'

@description('Fabric Capacity Admins')
param fabricCapacityAdmins array = []

@description('Set to true to deploy Microsoft Fabric Capacity and Workspace. Requires Fabric to be enabled in the tenant.')
param deployFabric bool = false

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    environment: environment
    managedBy: 'bicep'
    createdDate: deploymentTimestamp
  }
}

// Deploy hub VNet with VPN Gateway
module hubNetwork 'modules/hub-vnet.bicep' = {
  scope: rg
  name: 'hubNetworkDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Deploy spoke VNet
module spokeNetwork 'modules/spoke-vnet.bicep' = {
  scope: rg
  name: 'spokeNetworkDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Deploy on-premises simulation VNet with VPN Gateway
module onPremNetwork 'modules/onprem-vnet.bicep' = {
  scope: rg
  name: 'onPremNetworkDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Peer hub and spoke
module hubSpokepeering 'modules/vnet-peering.bicep' = {
  scope: rg
  name: 'hubSpokePeeringDeployment'
  params: {
    hubVNetName: hubNetwork.outputs.vnetName
    spokeVNetName: spokeNetwork.outputs.vnetName
  }
}

// Create VPN connection from hub to on-prem
module vpnConnections 'modules/vpn-connections.bicep' = {
  scope: rg
  name: 'vpnConnectionsDeployment'
  params: {
    hubVpnGatewayId: hubNetwork.outputs.vpnGatewayId
    onPremVpnGatewayId: onPremNetwork.outputs.vpnGatewayId
    onPremAddressPrefix: onPremNetwork.outputs.vnetAddressPrefix
    hubAddressPrefix: hubNetwork.outputs.vnetAddressPrefix
    hubVpnGatewayName: hubNetwork.outputs.vpnGatewayName
    onPremVpnGatewayName: onPremNetwork.outputs.vpnGatewayName
    location: location
  }
  dependsOn: [
    hubNetwork
    onPremNetwork
  ]
}

// Deploy Windows VM with SQL Server in spoke
module sqlServerVm 'modules/sql-vm.bicep' = {
  scope: rg
  name: 'sqlServerVmDeployment'
  params: {
    location: location
    environment: environment
    subnetId: onPremNetwork.outputs.workloadSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: 'Standard_B2s'
    sqlServerVersion: sqlServerVersion
  }
}

module fabric 'modules/fabric.bicep' = if (deployFabric) {
  scope: rg
  name: 'fabricDeployment'
  params: {
    location: location
    fabricCapacityName: fabricCapacityName
    workspaceName: workspaceName
    fabricCapacityAdmins: fabricCapacityAdmins
  }
}

// Private DNS Zone corp.contoso.com linked to on-prem and spoke VNets
module privateDnsZone 'modules/private-dns-zone.bicep' = {
  scope: rg
  name: 'privateDnsZoneDeployment'
  params: {
    onPremVnetId: onPremNetwork.outputs.vnetId
    spokeVnetId: spokeNetwork.outputs.vnetId
  }
}

@description('Fabric Capacity ID (empty when deployFabric is false)')
output fabricCapacityId string = deployFabric ? fabric.outputs.fabricCapacityId : ''

@description('Spoke VNet ID')
output spokeVNetId string = spokeNetwork.outputs.vnetId

@description('Spoke Load Balancer frontend IP configuration ID used by SQL Private Link Service')
output spokeLbFrontendIpConfigurationId string = spokeNetwork.outputs.loadBalancerFrontendIpConfigurationId

@description('SQL Private Link Service ID in spoke network')
output sqlPrivateLinkServiceId string = spokeNetwork.outputs.sqlPrivateLinkServiceId

@description('SQL Private Link Service Name in spoke network')
output sqlPrivateLinkServiceName string = spokeNetwork.outputs.sqlPrivateLinkServiceName

@description('On-Prem VNet ID')
output onPremVNetId string = onPremNetwork.outputs.vnetId

@description('SQL Server VM ID')
output sqlVmId string = sqlServerVm.outputs.vmId

@description('SQL Server VM Public IP')
output sqlVmPublicIp string = sqlServerVm.outputs.publicIpAddress

@description('SQL Server VM Name')
output sqlVmName string = sqlServerVm.outputs.vmName

@description('Private DNS Zone ID for corp.contoso.com')
output privateDnsZoneId string = privateDnsZone.outputs.privateDnsZoneId

@description('Private DNS Zone Name')
output privateDnsZoneName string = privateDnsZone.outputs.privateDnsZoneName
