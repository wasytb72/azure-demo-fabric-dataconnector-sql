# Customization Guide

## Overview

This guide explains how to customize the demo landing zone for your specific needs.

## Common Customizations

### 1. Change Deployment Regions

**Before:**
```bicep
param location string = 'eastus'
```

**After (for West Europe):**
```bicep
param location string = 'westeurope'
```

**Available Regions:**
- `eastus`, `westus`, `westus2`
- `northeurope`, `westeurope`, `uksouth`
- `southeastasia`, `australiaeast`
- See all: `az account list-locations`

---

### 2. Modify Network Address Spaces

**Hub VNet** - Edit `infra/modules/hub-vnet.bicep`:
```bicep
var vnetAddressPrefix = '10.100.0.0/16'      # Changed
var gatewaySubnetPrefix = '10.100.0.0/24'
var bastionSubnetPrefix = '10.100.1.0/24'
var firewallSubnetPrefix = '10.100.2.0/24'
var managementSubnetPrefix = '10.100.3.0/24'
```

**Spoke VNet** - Edit `infra/modules/spoke-vnet.bicep`:
```bicep
var vnetAddressPrefix = '10.101.0.0/16'      # Changed
var workloadSubnetPrefix = '10.101.0.0/24'
```

**On-Premises VNet** - Edit `infra/modules/onprem-vnet.bicep`:
```bicep
var vnetAddressPrefix = '172.16.0.0/16'      # Changed (non-overlapping)
var gatewaySubnetPrefix = '172.16.0.0/24'
var workloadSubnetPrefix = '172.16.1.0/24'
```

**Important:** All address spaces must be non-overlapping!

---

### 3. Change VM Size

**Edit** `infra/modules/sql-vm.bicep`:

```bicep
# Current (B2s - 2 vCPU, 4 GB RAM)
param vmSize string = 'Standard_B2s'

# For larger workloads (D2s - 2 vCPU, 8 GB RAM)
param vmSize string = 'Standard_D2s_v3'

# For production SQL (D4s - 4 vCPU, 16 GB RAM)
param vmSize string = 'Standard_D4s_v3'
```

**Size Options:**
| SKU | vCPU | RAM | Cost/Month |
|-----|------|-----|-----------|
| Standard_B1s | 1 | 1GB | $6 |
| Standard_B2s | 2 | 4GB | $35 |
| Standard_D2s_v3 | 2 | 8GB | $97 |
| Standard_D4s_v3 | 4 | 16GB | $193 |

---

### 4. Change SQL Server Version

**Edit** `infra/main.bicep`:

```bicep
# Current
param sqlServerVersion string = '2022-web'

# Options:
# '2019-enterprise'    - SQL Server 2019 Enterprise
# '2019-standard'      - SQL Server 2019 Standard
# '2019-web'           - SQL Server 2019 Web
# '2022-enterprise'    - SQL Server 2022 Enterprise
# '2022-standard'      - SQL Server 2022 Standard
# '2022-web'           - SQL Server 2022 Web (current)
```

---

### 5. Change Admin Credentials

**Option A: Command Line**
```bash
az deployment sub create \
  --template-file infra/main.bicep \
  --parameters \
    adminUsername="myuser" \
    adminPassword="NewSecurePassword123!"
```

**Option B: Parameters File** - Edit `infra/main.parameters.json`:
```json
{
  "adminUsername": {
    "value": "sqlservices"
  },
  "adminPassword": {
    "value": "NewSecurePassword123!"
  }
}
```

⚠️ **Security:** Never commit passwords to git! Use Azure Key Vault in production.

---

### 6. Add More Spokes

**Edit** `infra/main.bicep`:

```bicep
// Existing spoke
module spokeNetwork 'modules/spoke-vnet.bicep' = {
  scope: rg
  name: 'spokeNetworkDeployment'
  params: {
    location: location
    environment: environment
  }
}

// ADD NEW SPOKE
module spoke2Network 'modules/spoke-vnet.bicep' = {
  scope: rg
  name: 'spoke2NetworkDeployment'
  params: {
    location: location
    environment: environment
  }
}

// Peer new spoke to hub
module hub2Spoke2Peering 'modules/vnet-peering.bicep' = {
  scope: rg
  name: 'hubSpoke2PeeringDeployment'
  params: {
    hubVNetName: hubNetwork.outputs.vnetName
    spokeVNetName: spoke2Network.outputs.vnetName
  }
}
```

**Important:** Update module to use different names:
- Rename `spoke-vnet.bicep` → `spoke2-vnet.bicep`
- Change address prefix (e.g., `10.2.0.0/16`)

---

### 7. Change VPN Gateway SKU

**Edit** `infra/modules/hub-vnet.bicep` and `onprem-vnet.bicep`:

```bicep
# Current (VpnGw2 - $95/month)
sku: {
  name: 'VpnGw2'
  tier: 'VpnGw2'
}

# For lower cost (VpnGw1 - $50/month, lower throughput)
sku: {
  name: 'VpnGw1'
  tier: 'VpnGw1'
}

# For higher performance (VpnGw3 - $145/month)
sku: {
  name: 'VpnGw3'
  tier: 'VpnGw3'
}
```

**Gateway Options:**
| SKU | Throughput | Cost | Use Case |
|-----|-----------|------|----------|
| VpnGw1 | 650 Mbps | $50 | Small demo |
| VpnGw2 | 1.25 Gbps | $95 | Typical |
| VpnGw3 | 2.5 Gbps | $145 | High traffic |

---

### 8. Add Azure Firewall to Hub

**Create** `infra/modules/firewall.bicep`:

```bicep
@description('Location for resources')
param location string

@description('Hub VNet name')
param hubVNetName string

var firewallName = 'fw-hub-demo'
var publicIpName = 'pip-fw-hub-demo'

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${resourceId('Microsoft.Network/virtualNetworks', hubVNetName)}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output firewallId string = firewall.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
```

**Then add to** `infra/main.bicep`:

```bicep
module firewall 'modules/firewall.bicep' = {
  scope: rg
  name: 'firewallDeployment'
  params: {
    location: location
    hubVNetName: hubNetwork.outputs.vnetName
  }
  dependsOn: [
    hubNetwork
  ]
}
```

---

### 9. Enable Network Monitoring

**Create** `infra/modules/monitoring.bicep`:

```bicep
@description('Location for resources')
param location string

@description('Hub VNet ID')
param hubVNetId string

var lawName = 'law-hub-demo'
var nwwName = 'nww-hub-demo'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' = {
  name: nwwName
  location: location
  properties: {}
}

output workspaceId string = logAnalyticsWorkspace.id
output networkWatcherId string = networkWatcher.id
```

---

### 10. Create Multiple Environments

**Create parameter files for each environment:**

`infra/main.parameters.prod.json`:
```json
{
  "resourceGroupName": {
    "value": "rg-landing-zone-prod"
  },
  "location": {
    "value": "westeurope"
  },
  "environment": {
    "value": "prod"
  },
  "sqlServerVersion": {
    "value": "2022-enterprise"
  }
}
```

`infra/main.parameters.dev.json`:
```json
{
  "resourceGroupName": {
    "value": "rg-landing-zone-dev"
  },
  "location": {
    "value": "eastus"
  },
  "environment": {
    "value": "dev"
  },
  "sqlServerVersion": {
    "value": "2022-web"
  }
}
```

**Deploy each:**
```bash
# Production
az deployment sub create \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.prod.json

# Development
az deployment sub create \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.dev.json
```

---

## Advanced Customizations

### Custom NSG Rules

**Edit** `infra/modules/spoke-vnet.bicep`:

```bicep
securityRules: [
  {
    name: 'AllowHTTP'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 200
      direction: 'Inbound'
    }
  },
  {
    name: 'AllowHTTPS'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 201
      direction: 'Inbound'
    }
  }
  // Add your custom rules
]
```

### Custom VM Extensions

**Edit** `infra/modules/sql-vm.bicep`:

```bicep
// Add custom extension after SqlIaasExtension
resource customExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'CustomExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      fileUris: [
        'https://storageaccount.blob.core.windows.net/scripts/setup.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File setup.ps1'
    }
  }
}
```

---

## Testing Your Changes

After customization:

```bash
# 1. Validate Bicep
az bicep build --file infra/main.bicep

# 2. Validate template
az deployment sub validate \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json

# 3. What-if analysis (preview changes)
az deployment sub what-if \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json

# 4. Deploy
az deployment sub create \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json
```

---

## Troubleshooting Customizations

### Error: Invalid address prefix
```
Ensure all subnets fit within VNet address space
Example: VNet 10.0.0.0/16 cannot contain subnet 10.1.0.0/24
```

### Error: Duplicate resource names
```
Use unique names for each resource
Example: vnet-hub-prod, vnet-hub-dev (not vnet-hub for both)
```

### Deployment stuck at VPN Gateway
```
VPN Gateways take 15-20 minutes to provision
Monitor in Azure Portal > Virtual Network Gateways
```

---

## Version Control Best Practices

```bash
# 1. Create branch for customizations
git checkout -b feature/custom-spokes

# 2. Make changes
# Edit files as needed

# 3. Test before committing
az bicep build --file infra/main.bicep
az deployment sub validate ...

# 4. Commit
git add infra/
git commit -m "feat: add additional spoke network"

# 5. Merge to main
git checkout main
git merge feature/custom-spokes
```

---

## When to Use What

| Scenario | Customization |
|----------|---------------|
| Different region | Change `location` parameter |
| Multiple environments | Create separate parameter files |
| Add managed services (DB, App Service) | Add new modules |
| Change security rules | Edit NSG rules in module |
| Larger production deployment | Increase VM size, gateway SKU |
| Development/testing only | Use B1s VM, VpnGw1 gateway |

---

**Need help?** Refer to [ARCHITECTURE.md](ARCHITECTURE.md) for more details on each component.
