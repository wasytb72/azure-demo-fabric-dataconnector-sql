@description('On-premises VNet ID to link to the private DNS zone')
param onPremVnetId string

@description('Spoke VNet ID to link to the private DNS zone')
param spokeVnetId string

var privateDnsZoneName = 'corp.contoso.com'

// Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

// VNet link to on-premises VNet
resource onPremVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-onprem'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: onPremVnetId
    }
    registrationEnabled: true
  }
}

// VNet link to spoke VNet
resource spokeVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spokeVnetId
    }
    registrationEnabled: false
  }
}

@description('Private DNS Zone ID')
output privateDnsZoneId string = privateDnsZone.id

@description('Private DNS Zone Name')
output privateDnsZoneName string = privateDnsZone.name
