# Quick Start: Deployment Guide

## Prerequisites Checklist

- [ ] Azure CLI installed (`az --version`)
- [ ] Logged into Azure (`az login`)
- [ ] Target subscription selected (`az account set --subscription <id>`)
- [ ] Sufficient quota for 2 VPN Gateways and 1 VM
- [ ] ~30 minutes for deployment

## One-Command Deployment

```powershell
# Set your variables
$rg = "rg-landing-zone-demo"
$location = "eastus"
$adminPass = "NewSecurePassword123!"

# Deploy
az deployment sub create `
  --location $location `
  --template-file infra/main.bicep `
  --parameters `
    resourceGroupName=$rg `
    location=$location `
    adminPassword=$adminPass

# Wait 25-30 minutes for VPN Gateways to provision
```

## Step-by-Step Deployment

### 1. Validate Templates
```bash
az bicep build --file infra/main.bicep
```

### 2. Run Preflight Check
```bash
az deployment sub validate `
  --location eastus `
  --template-file infra/main.bicep `
  --parameters `
    resourceGroupName="rg-landing-zone-demo" `
    location="eastus" `
    adminPassword="NewSecurePassword123!"
```

### 3. Create Deployment
```bash
az deployment sub create `
  --name "hub-spoke-deployment" `
  --location eastus `
  --template-file infra/main.bicep `
  --parameters infra/main.parameters.json `
  --parameters adminPassword="NewSecurePassword123!"
```

### 4. Monitor Progress
```bash
# Watch deployment status
az deployment sub show `
  --name "hub-spoke-deployment" `
  --query "properties.provisioningState"

# View all resources being created
az resource list --resource-group rg-landing-zone-demo
```

## After Deployment

### Get Output Values
```bash
az deployment sub show `
  --name "hub-spoke-deployment" `
  --query "properties.outputs"
```

### Connect to SQL VM
```bash
# Get the public IP
$sqlVmIp = az deployment sub show `
  --name "hub-spoke-deployment" `
  --query "properties.outputs.sqlVmPublicIp.value" `
  -o tsv

# RDP Connection
mstsc /v:$sqlVmIp

# Credentials
# Username: demoadmin
# Password: NewSecurePassword123!
```

### Verify VPN Status
```bash
az network vpn-connection list `
  --resource-group rg-landing-zone-demo `
  --query "[].{Name:name, Status:connectionStatus}"
```

## Cleanup

```bash
# Delete all resources
az group delete `
  --resource-group rg-landing-zone-demo `
  --yes

# Delete the deployment history
az deployment sub delete `
  --name "hub-spoke-deployment"
```

## Cost Estimation

| Resource | Estimated Cost/Month |
|----------|---------------------|
| VPN Gateway (2x) | $190 |
| Standard_B2s VM | $35 |
| Public IPs (3x) | $10 |
| **Total** | **~$235** |

*Note: Costs vary by region. Multiply by daily active hours for part-time deployments.*

## Troubleshooting

### Deployment Failed
1. Check quota: `az vm list-usage --location eastus`
2. Validate templates: `az bicep build --file infra/main.bicep`
3. Check Resource Provider registration: `az provider register -n Microsoft.Network`

### VPN Won't Connect
1. Verify gateway public IPs are active
2. Check local network gateway addresses
3. Verify shared key is configured
4. Wait for gateway provisioning (15-20 min)

### Cannot RDP to VM
1. Check VM is running: `az vm list --resource-group rg-landing-zone-demo`
2. Verify NSG rules: `az network nsg rule list --resource-group rg-landing-zone-demo`
3. Ensure public IP is assigned
4. Check RDP port in firewall

## What Gets Created

### Networking
- Hub VNet (10.0.0.0/16)
- Spoke VNet (10.1.0.0/16)
- On-Prem VNet (192.168.0.0/16)
- VNet Peering (Hub ↔ Spoke)
- Site-to-Site VPN (Hub ↔ On-Prem)

### Security
- 3 Network Security Groups (NSGs)
- 3 Public IP Addresses
- 2 VPN Gateways

### Compute
- 1 Windows Server 2022 VM
- SQL Server 2022 Web Edition
- 1 OS Disk (Premium SSD)
- 1 Data Disk (128GB Premium SSD)

## Next Steps

After successful deployment:

1. **Configure SQL Security**
   - Enable SQL Server Authentication
   - Create login and user accounts
   - Configure SQL Server firewall

2. **Test Connectivity**
   - RDP to the VM
   - Query SQL Server
   - Test VPN tunnel

3. **Enable Monitoring**
   - Azure Monitor for VM metrics
   - Log Analytics for diagnostics
   - Application Insights for SQL monitoring

4. **Production Hardening**
   - Change default shared key
   - Enable NSG flow logs
   - Implement Azure Bastion
   - Configure Azure Firewall
   - Enable resource locks

---

**Deployment Time**: ~25-30 minutes
**Estimated Cost**: ~$235/month
