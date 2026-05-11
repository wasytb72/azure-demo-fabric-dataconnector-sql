@description('Hub VPN Gateway ID')
param hubVpnGatewayId string

@description('On-Prem VPN Gateway ID')
param onPremVpnGatewayId string

@description('On-Prem address prefix')
param onPremAddressPrefix string

@description('Hub address prefix')
param hubAddressPrefix string

@description('Hub VPN Gateway name')
param hubVpnGatewayName string

@description('On-Prem VPN Gateway name')
param onPremVpnGatewayName string

@description('Location for resources')
param location string

var sharedKey = 'P@ssw0rdDemo123!'
var hubLocalGatewayName = 'lgw-${onPremVpnGatewayName}'
var onPremLocalGatewayName = 'lgw-${hubVpnGatewayName}'

// Reference hub VPN gateway
resource hubVpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' existing = {
  name: hubVpnGatewayName
}

// Reference on-prem VPN gateway
resource onPremVpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' existing = {
  name: onPremVpnGatewayName
}

// Get public IPs from gateways
resource hubGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
  name: 'pip-vpngw-hub-demo'
}

resource onPremGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
  name: 'pip-vpngw-onprem-demo'
}

// Local Gateway Network for On-Prem (as seen from Hub)
resource hubLocalGateway 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: hubLocalGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        onPremAddressPrefix
      ]
    }
    gatewayIpAddress: onPremGatewayPublicIp.properties.ipAddress
  }
}

// Local Gateway Network for Hub (as seen from On-Prem)
resource onPremLocalGateway 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: onPremLocalGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        hubAddressPrefix
      ]
    }
    gatewayIpAddress: hubGatewayPublicIp.properties.ipAddress
  }
}

// VPN Connection from Hub to On-Prem
resource hubToOnPremConnection 'Microsoft.Network/connections@2023-11-01' = {
  name: 'conn-hub-to-onprem'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: hubVpnGatewayId
    }
    localNetworkGateway2: {
      id: hubLocalGateway.id
    }
    sharedKey: sharedKey
    connectionProtocol: 'IKEv2'
    enableBgp: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: []
  }
}

// VPN Connection from On-Prem to Hub
resource onPremToHubConnection 'Microsoft.Network/connections@2023-11-01' = {
  name: 'conn-onprem-to-hub'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: onPremVpnGatewayId
    }
    localNetworkGateway2: {
      id: onPremLocalGateway.id
    }
    sharedKey: sharedKey
    connectionProtocol: 'IKEv2'
    enableBgp: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: []
  }
}

@description('Hub to On-Prem Connection ID')
output hubToOnPremConnectionId string = hubToOnPremConnection.id

@description('On-Prem to Hub Connection ID')
output onPremToHubConnectionId string = onPremToHubConnection.id

@description('Shared VPN Key')
output sharedKey string = sharedKey
