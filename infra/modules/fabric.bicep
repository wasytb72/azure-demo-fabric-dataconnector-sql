param location string = resourceGroup().location
param fabricCapacityName string
param workspaceName string
param fabricCapacityAdmins array = []

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: fabricCapacityName
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

resource workspace 'Microsoft.Fabric/workspaces@2023-11-01' = {
  name: workspaceName
  location: location
  properties: {
    capacityObjectId: fabricCapacity.id
  }
}

output fabricCapacityId string = fabricCapacity.id
output workspaceId string = workspace.id
