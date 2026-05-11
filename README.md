# Azure Hub-Spoke Landing Zone Demo with VPN and SQL Server

This demo deployment creates a comprehensive hub-spoke network topology in Azure with site-to-site VPN connectivity simulating an on-premises environment.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Cloud                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────┐         ┌──────────────────────┐  │
│  │   HUB VNET               │         │   SPOKE VNET         │  │
│  │   10.0.0.0/16            │         │   10.1.0.0/16        │  │
│  ├──────────────────────────┤         ├──────────────────────┤  │
│  │ • GatewaySubnet          │         │ • snet-workload      │  │
│  │ • AzureBastionSubnet     │<───────>│   (SQL Server VM)    │  │
│  │ • AzureFirewallSubnet    │ Peering │                      │  │
│  │ • Management Subnet      │         │                      │  │
│  │                          │         │                      │  │
│  │ [VPN Gateway]            │         │  [SQL Server VM]     │  │
│  └──────────────────────────┘         │  • IP: Dynamic       │  │
│         ↑                               │  • Public IP         │  │
│         │ S2S VPN Tunnel                └──────────────────────┘  │
│         │ (IKEv2)                                                 │
│         ↓                                                         │
│  ┌──────────────────────────┐                                    │
│  │   ON-PREM VNET           │                                    │
│  │   192.168.0.0/16         │                                    │
│  ├──────────────────────────┤                                    │
│  │ • GatewaySubnet          │                                    │
│  │ • snet-workload          │                                    │
│  │                          │                                    │
│  │ [VPN Gateway]            │                                    │
│  └──────────────────────────┘                                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Components Deployed

### Networking
- **Hub VNet** (10.0.0.0/16)
  - Gateway Subnet for VPN connectivity
  - Azure Bastion Subnet (reserved for future use)
  - Azure Firewall Subnet (reserved for future use)
  - Management Subnet

- **Spoke VNet** (10.1.0.0/16)
  - Workload Subnet hosting the SQL Server VM
  - Connected to Hub via VNet Peering

- **On-Premises Simulation VNet** (192.168.0.0/16)
  - Simulates on-premises environment
  - Connected to Hub via Site-to-Site VPN

### VPN Gateway Configuration
- **Hub VPN Gateway**: RouteBased, VpnGw2 SKU
- **On-Prem VPN Gateway**: RouteBased, VpnGw2 SKU
- **VPN Protocol**: IKEv2
- **Shared Key**: P@ssw0rdDemo123!

### Compute
- **SQL Server VM** in Spoke VNet
  - Windows Server 2022 with SQL Server 2022 Web Edition
  - Size: Standard_B2s (2 vCPU, 4GB RAM)
  - Premium SSD for OS and Data disks
  - Public IP address for RDP/SQL access
  - SQL Server Management Tools pre-installed

## Prerequisites

- Azure subscription
- Azure CLI or Azure PowerShell installed
- Bicep CLI installed (for building/validation)
- Sufficient quota for:
  - 3 Virtual Networks
  - 2 VPN Gateways
  - 1 Virtual Machine
  - 3 Public IPs

## Deployment Instructions

### Option 1: Using Azure CLI

1. **Set variables**
```bash
$resourceGroupName = "rg-landing-zone-demo"
$location = "eastus"
$adminPassword = "YourSecurePassword123!"
```

2. **Deploy subscription-scope deployment**
```bash
az deployment sub create `
  --location $location `
  --template-file infra/main.bicep `
  --parameters `
    resourceGroupName=$resourceGroupName `
    location=$location `
    adminPassword=$adminPassword
```

### Option 2: Using Azure PowerShell

```powershell
$parameters = @{
    TemplateFile = "infra/main.bicep"
    Location = "eastus"
    TemplateParameterObject = @{
        resourceGroupName = "rg-landing-zone-demo"
        location = "eastus"
        adminUsername = "demoadmin"
        adminPassword = "YourSecurePassword123!"
    }
}

New-AzSubscriptionDeployment @parameters
```

### Option 3: Using Azure Portal

1. Navigate to **Subscriptions**
2. Select **Deployments** > **Create**
3. Select **Bicep file** and upload `infra/main.bicep`
4. Fill in the parameters
5. Review and create

## Estimated Deployment Time

- VPN Gateways: 15-20 minutes (longest resource)
- VM and other resources: 5-10 minutes
- **Total**: ~25-30 minutes

## Post-Deployment Steps

### 1. Verify VPN Connection Status
```bash
az network vpn-connection show `
  --resource-group rg-landing-zone-demo `
  --name conn-hub-to-onprem `
  --query "connectionStatus"
```

### 2. Connect to SQL Server VM
- Retrieve the public IP from deployment outputs
- Use RDP (port 3389) to connect
- Default credentials: `demoadmin / P@ssw0rdDemo123!`

### 3. Connect to SQL Server
- SQL Server Management Studio (SSMS) pre-installed
- Connection: `<PublicIP>,1433`
- Windows Authentication available

### 4. Verify Network Connectivity
From SQL VM, test connectivity to on-premises:
```powershell
Test-NetConnection -ComputerName 192.168.1.1 -Port 1433
```

## Security Considerations

1. **NSG Rules**: All subnets have configured Network Security Groups
   - RDP (3389) open for management
   - SQL (1433) restricted to VNet traffic for spoke
   - Allow rules for virtual network traffic

2. **SQL Server Access**
   - Configure SQL authentication in addition to Windows
   - Consider using private endpoints in production
   - Implement SQL Server firewall rules

3. **VPN Security**
   - Shared key is demo-only; use Azure Key Vault in production
   - Consider enabling BGP for dynamic routing
   - Implement DPD (Dead Peer Detection)

4. **VM Security**
   - Enable Azure Disk Encryption
   - Configure Windows Firewall rules
   - Implement regular patching via Azure Update Management

## Cost Optimization

This demo uses:
- **Standard B2s VM**: ~$0.05/hour
- **VPN Gateways**: ~$0.32/hour each (minimum 2)
- **VNet Peering**: Free
- **Data Transfer**: Minimal for demo purposes

**Estimated monthly cost**: ~$200-250

To reduce costs:
- Use smaller VM size (Standard_B1s) for on-prem simulation
- Delete resources when not in use
- Consider using App Service or Functions instead of VM

## Cleanup

To remove all resources:
```bash
az group delete --resource-group rg-landing-zone-demo --yes
```

⚠️ **Warning**: This will delete all resources in the resource group, including the VMs and data.

## Troubleshooting

### VPN Connection Not Established
1. Check firewall rules on local network gateways
2. Verify pre-shared key matches on both sides
3. Check VPN gateway public IPs are correctly referenced
4. Review connection diagnostics in Azure Portal

### Cannot Reach SQL Server
1. Verify SQL Server service is running on the VM
2. Check SQL Server port 1433 is listening
3. Confirm NSG rules allow traffic
4. Verify firewall rules on Windows VM

### VM Deployment Fails
1. Check quota for VM size in region
2. Verify subnet has available IP addresses
3. Check subnet NSG rules allow traffic

## File Structure

```
.
├── infra/
│   ├── main.bicep              # Main deployment orchestrator
│   ├── main.parameters.json    # Parameter file
│   └── modules/
│       ├── hub-vnet.bicep      # Hub VNet with VPN Gateway
│       ├── spoke-vnet.bicep    # Spoke VNet
│       ├── onprem-vnet.bicep   # On-premises simulation VNet
│       ├── vnet-peering.bicep  # Hub-Spoke VNet peering
│       ├── vpn-connections.bicep # VPN connections
│       └── sql-vm.bicep        # SQL Server VM
├── README.md                   # This file
└── docs/                       # Additional documentation
```

## References

- [Azure Hub-Spoke Architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [VPN Gateway Documentation](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways)
- [SQL Server on Azure VMs](https://learn.microsoft.com/en-us/azure/azure-sql/virtual-machines/windows/sql-server-on-azure-vm-iaas-what-is-overview)
- [VNet Peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)

## Support

For issues or questions:
1. Check Azure Activity Log for deployment errors
2. Review NSG flow logs for connectivity issues
3. Use Connection Monitor to diagnose VPN connectivity
4. Check VPN Gateway connection status in Azure Portal

---

**Demo Created**: May 2026
**Last Updated**: May 5, 2026
