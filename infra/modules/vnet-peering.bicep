@description('Hub VNet name')
param hubVNetName string

@description('Spoke VNet name')
param spokeVNetName string

// Reference to hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: hubVNetName
}

// Reference to spoke VNet
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: spokeVNetName
}

// Hub to Spoke peering
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: hubVnet
  name: 'peer-hub-to-spoke'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
  }
}

// Spoke to Hub peering
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: spokeVnet
  name: 'peer-spoke-to-hub'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
}

@description('Hub to Spoke Peering ID')
output hubToSpokePeeringId string = hubToSpokePeering.id

@description('Spoke to Hub Peering ID')
output spokeToHubPeeringId string = spokeToHubPeering.id
