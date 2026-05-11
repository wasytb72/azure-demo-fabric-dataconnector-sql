# Landing Zone Demo - Project Summary

## Overview

This project provides a complete, production-grade Infrastructure-as-Code (IaC) template for deploying an Azure hub-spoke network topology with site-to-site VPN connectivity and SQL Server.

**Perfect for:**
- Learning hub-spoke networking patterns
- Demonstrating hybrid cloud connectivity
- Testing cross-premises scenarios
- POCs and demos
- Training environments

## Project Structure

```
landing-zone-demo/
├── README.md                          # Main documentation
├── DEPLOYMENT.md                      # Quick start guide
├── ARCHITECTURE.md                    # Detailed architecture
├── PROJECT-SUMMARY.md                 # This file
├── deploy.ps1                         # PowerShell deployment script
├── deploy.sh                          # Bash deployment script
├── infra/
│   ├── main.bicep                     # Main orchestration template
│   ├── main.parameters.json           # Parameters file
│   └── modules/
│       ├── hub-vnet.bicep             # Hub VNet + VPN Gateway
│       ├── spoke-vnet.bicep           # Spoke VNet
│       ├── onprem-vnet.bicep          # On-prem simulation VNet
│       ├── vnet-peering.bicep         # Hub-spoke peering
│       ├── vpn-connections.bicep      # VPN connections
│       └── sql-vm.bicep               # SQL Server VM
└── .azure/
    └── [deployment outputs]
```

## Key Features

### ✅ Networking
- **Hub-Spoke Topology**: Central hub for management, spokes for workloads
- **VNet Peering**: Direct connectivity between hub and spoke
- **Site-to-Site VPN**: IPSec tunnel between hub and on-premises simulation
- **Gateway Transit**: Spoke VMs can reach on-premises via hub gateway
- **Network Security**: NSGs on all subnets with sensible defaults

### ✅ VPN Connectivity
- **Two VPN Gateways**: Hub (10.0.0.0/16) and On-Prem (192.168.0.0/16)
- **IKEv2 Protocol**: Modern, secure encryption
- **Local Network Gateways**: Represent remote networks
- **Automated Setup**: No manual gateway configuration needed

### ✅ SQL Server
- **Windows Server 2022**: Latest OS with security updates
- **SQL Server 2022 Web Edition**: Enterprise-grade database
- **Public IP**: Direct internet access (for demo only)
- **Premium Storage**: SSD for performance
- **Pre-configured**: SSMS and tools included

### ✅ IaC Best Practices
- **Modular Design**: Reusable Bicep modules
- **Parameter-driven**: Easy customization
- **Subscription-scope**: Single deployment command
- **Tagged Resources**: Organized resource management
- **No hard-coded values**: Everything parameterized

## Quick Start

### Prerequisites
```bash
# Install Azure CLI
# https://learn.microsoft.com/cli/azure/install-azure-cli

# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>
```

### One-Command Deployment (PowerShell)
```powershell
.\deploy.ps1 -AdminPassword "YourSecurePassword123!"
```

### One-Command Deployment (Bash)
```bash
./deploy.sh rg-landing-zone-demo eastus YourSecurePassword123!
```

### Manual Deployment
```bash
az deployment sub create \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters \
    resourceGroupName="rg-landing-zone-demo" \
    location="eastus" \
    adminPassword="YourSecurePassword123!"
```

**Deployment Time**: ~25-30 minutes
**Estimated Cost**: ~$270/month

## What Gets Created

### Networking (Free to Low Cost)
| Resource | Qty | Purpose |
|----------|-----|---------|
| Virtual Networks | 3 | Hub, Spoke, On-Prem simulation |
| Subnets | 6 | Various roles (Gateway, Workload, etc.) |
| Network Security Groups | 3 | Ingress/egress filtering |
| VNet Peerings | 2 | Hub↔Spoke bidirectional |
| Public IP Addresses | 3 | VPN Gateways + SQL VM |

### Compute & Storage (~$270/month)
| Resource | Qty | Size | Purpose |
|----------|-----|------|---------|
| VPN Gateways | 2 | VpnGw2 | Site-to-site VPN |
| Virtual Machines | 1 | Standard_B2s | SQL Server |
| Managed Disks | 2 | 128GB Premium | OS + Data |
| Local Network Gateways | 2 | Standard | Represent remote networks |

## Use Cases

### 1. Hybrid Cloud Setup
Test scenarios where Azure extends on-premises infrastructure:
- Database replication across sites
- DR and failover procedures
- Backup routing via VPN

### 2. Migration POC
Demonstrate Azure connectivity for migration projects:
- Run SQL workloads in Azure
- Maintain on-premises connectivity
- Test performance and latency

### 3. Learning & Training
Understand Azure networking:
- Hub-spoke topology patterns
- VPN gateway configuration
- Network peering and routing
- Security group configuration

### 4. Load Testing
Performance testing with SQL workloads:
- High availability scenarios
- Database replication testing
- Network failover testing

## Customization Options

### Change VM Size
Edit `infra/modules/sql-vm.bicep`:
```bicep
param vmSize string = 'Standard_D2s_v3'  # Larger VM
```

### Add More Spokes
Duplicate spoke module in `infra/main.bicep`:
```bicep
module additionalSpoke 'modules/spoke-vnet.bicep' = {
  // Deploy additional spoke networks
}
```

### Modify Address Space
Edit VNet CIDR ranges in module files:
```bicep
var vnetAddressPrefix = '10.5.0.0/16'  // Different space
```

### Enable Azure Firewall
Add firewall subnet and resources:
```bicep
// In hub-vnet.bicep
// Deploy Azure Firewall to AzureFirewallSubnet
```

## Security Considerations

### Production Hardening

1. **Change Default Credentials**
   - Update admin password in parameters
   - Store in Azure Key Vault
   - Rotate regularly

2. **Enable Monitoring**
   - Azure Monitor for VMs
   - Log Analytics for diagnostics
   - Alert on anomalies

3. **Restrict Access**
   - Use Azure Bastion instead of public IPs
   - Implement Azure Firewall
   - Use Service Endpoints and Private Endpoints
   - Restrict NSG rules to specific sources

4. **Encrypt Data**
   - Enable Azure Disk Encryption
   - Enable SQL TDE (Transparent Data Encryption)
   - Use encrypted connections

5. **Secure VPN**
   - Store shared key in Key Vault
   - Enable BGP for dynamic routing
   - Configure DPD (Dead Peer Detection)
   - Use ExpressRoute for production

### Current Limitations (Demo)
- ⚠️ RDP open to internet (use Bastion in production)
- ⚠️ SQL port open to internet (restrict to VNet)
- ⚠️ Shared key in parameters (use Key Vault)
- ⚠️ Standard B2s VM (too small for production SQL)

## Troubleshooting Guide

### Deployment Fails
```bash
# Check quota
az vm list-usage --location eastus

# Validate template
az bicep build --file infra/main.bicep

# View deployment errors
az deployment sub show --name <deployment-name> --query "properties.error"
```

### VPN Won't Connect
```bash
# Check gateway status
az network vpn-gateway list --resource-group rg-landing-zone-demo

# View connection status
az network vpn-connection list --resource-group rg-landing-zone-demo \
  --query "[].{Name:name,Status:connectionStatus}"

# Common causes:
# 1. Gateways still provisioning (15-20 min)
# 2. Firewall blocking IKEv2 (UDP 500, 4500)
# 3. Shared key mismatch
# 4. Wrong address prefixes in local gateways
```

### Cannot RDP to SQL VM
```bash
# Check VM is running
az vm list --resource-group rg-landing-zone-demo

# Get public IP
az network public-ip list --resource-group rg-landing-zone-demo \
  --query "[?name=='pip-sql-demo'].ipAddress"

# Verify NSG allows RDP
az network nsg rule list --resource-group rg-landing-zone-demo \
  --nsg-name nsg-sql-vm-demo --query "[].{Name:name,Port:destinationPortRange,Access:access}"
```

## Cost Optimization

### Save Money
1. **Stop VM when not in use**
   ```bash
   az vm deallocate --resource-group rg-landing-zone-demo --name vm-sql-demo
   ```

2. **Use smaller VM for testing**
   - Standard_B1s: $6/month (vs $35 for B2s)
   - Still supports SQL Server, just limited

3. **Delete resources when done**
   ```bash
   az group delete --resource-group rg-landing-zone-demo --yes
   ```

4. **Use spot VMs for non-production**
   - Up to 90% cheaper but can be preempted

### Monthly Cost Breakdown
| Item | Cost |
|------|------|
| Hub VPN Gateway (VpnGw2) | $95 |
| On-Prem VPN Gateway (VpnGw2) | $95 |
| SQL Server VM (B2s) | $35 |
| Storage (2x 128GB Premium) | $30 |
| Public IPs (3x) | $15 |
| Data Transfer | $0-5 |
| **Total** | **~$270** |

*Running 8 hours/day: ~$70/month*
*Running 2 hours/day: ~$18/month*

## Documentation Index

- **[README.md](README.md)** - Complete architecture and deployment guide
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Quick start and step-by-step instructions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed network design and configuration
- **[PROJECT-SUMMARY.md](PROJECT-SUMMARY.md)** - This file

## Support & Resources

### Microsoft Learn
- [Hub-Spoke Architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/)
- [SQL Server on Azure VMs](https://learn.microsoft.com/en-us/azure/azure-sql/virtual-machines/windows/)

### Scripts Provided
- **deploy.ps1** - PowerShell automated deployment with validation
- **deploy.sh** - Bash automated deployment with validation

### Common Commands
```bash
# View all resources
az resource list --resource-group rg-landing-zone-demo

# View VPN connection status
az network vpn-connection list --resource-group rg-landing-zone-demo \
  --query "[].{Name:name, Status:connectionStatus}"

# Connect to SQL VM via RDP
mstsc /v:<public-ip>

# Clean up everything
az group delete --resource-group rg-landing-zone-demo --yes
```

## Next Steps

1. **Deploy the infrastructure**
   - Run deployment script or CLI command
   - Wait for VPN gateways to provision (~20 min)

2. **Test connectivity**
   - RDP to SQL Server VM
   - Query SQL databases
   - Test on-premises connectivity

3. **Customize for your needs**
   - Modify network ranges
   - Add more spokes
   - Implement additional services

4. **Secure for production**
   - Enable Azure Firewall
   - Set up monitoring
   - Implement private endpoints
   - Store secrets in Key Vault

5. **Scale up**
   - Add more VMs to spoke
   - Implement load balancing
   - Deploy additional workloads

## Version History

| Date | Version | Changes |
|------|---------|---------|
| May 5, 2026 | 1.0 | Initial release |

---

**Built with**: Azure Bicep, Azure CLI
**Tested on**: Azure CLI 2.x, PowerShell 7.x, Bash 5.x
**Compatibility**: All Azure regions

**Questions?** Refer to the README.md or ARCHITECTURE.md files for detailed information.
