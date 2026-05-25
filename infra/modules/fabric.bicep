param location string = resourceGroup().location
param fabricCapacityName string
param fabricCapacityAdmins array = []

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: '${fabricCapacityName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'F2'
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: fabricCapacityAdmins
    }
  }
}

output fabricCapacityId string = fabricCapacity.id
