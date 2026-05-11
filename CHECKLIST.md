# Pre-Deployment & Post-Deployment Checklist

## ✅ Pre-Deployment Checklist

### Prerequisites
- [ ] Azure subscription created
- [ ] Az CLI installed (`az --version` returns version 2.x or later)
- [ ] PowerShell 7.x installed (if using PS script)
- [ ] Logged into Azure (`az login`)
- [ ] Correct subscription selected (`az account show`)
- [ ] Sufficient quota for VMs and VPN Gateways
- [ ] Secure, complex admin password prepared

### Repository
- [ ] All files present in `infra/` directory
- [ ] `main.bicep` and all modules verified
- [ ] `main.parameters.json` reviewed
- [ ] Deployment scripts (`deploy.ps1`, `deploy.sh`) are executable

### Configuration Review
- [ ] Resource group name finalized
- [ ] Azure region selected (default: eastus)
- [ ] Admin username acceptable (default: demoadmin)
- [ ] Admin password meets Azure requirements:
  - [ ] At least 12 characters
  - [ ] Upper case letter
  - [ ] Lower case letter
  - [ ] Number
  - [ ] Special character (!@#$%^&*)

### Network Planning
- [ ] No IP conflicts with existing networks:
  - [ ] Hub VNet: 10.0.0.0/16
  - [ ] Spoke VNet: 10.1.0.0/16
  - [ ] On-Prem VNet: 192.168.0.0/16
- [ ] Firewall rules understood
- [ ] VPN requirements confirmed

### Cost Review
- [ ] Aware deployment costs ~$270/month
- [ ] Budget approved for testing period
- [ ] Understood how to stop/delete resources
- [ ] Identified cost-saving options if needed

### Documentation
- [ ] Read `README.md` (architecture overview)
- [ ] Reviewed `DEPLOYMENT.md` (deployment options)
- [ ] Scanned `ARCHITECTURE.md` (network design)

---

## 🚀 Deployment Steps Checklist

### Pre-Deployment Validation
- [ ] Validate Bicep syntax: `az bicep build --file infra/main.bicep`
- [ ] Run template validation: `az deployment sub validate ...`
- [ ] (Optional) Preview with what-if: `az deployment sub what-if ...`
- [ ] All checks passed

### Deployment Execution
- [ ] Confirm admin password noted securely
- [ ] Confirm resource group name correct
- [ ] Confirm region appropriate
- [ ] Deployment initiated (PowerShell, Bash, or CLI)
- [ ] Deployment name/ID captured for tracking

### During Deployment (25-30 minutes)
- [ ] Monitor progress in terminal or Azure Portal
- [ ] VPN Gateway provisioning started (15-20 min)
- [ ] Other resources deploying in parallel
- [ ] No intervention needed during deployment

### After Deployment Complete
- [ ] Deployment status: "Succeeded"
- [ ] No errors in deployment output
- [ ] Deployment outputs retrieved
- [ ] Capture outputs:
  - [ ] SQL VM Public IP
  - [ ] SQL VM Name
  - [ ] Network IDs
  - [ ] VPN Gateway IDs

---

## ✅ Post-Deployment Checklist

### 1. Verify Resources Created
- [ ] Resource group exists: `az group show -n rg-landing-zone-demo`
- [ ] Resource count correct: `az resource list -g rg-landing-zone-demo --query "length([])"`
- [ ] No failed deployments: `az deployment sub list --query "[?properties.provisioningState=='Failed']"`

### 2. Verify Network Components
```bash
# Hub VNet
- [ ] Hub VNet exists: vnet-hub-demo
- [ ] Hub subnets created (4 total):
  - [ ] GatewaySubnet
  - [ ] AzureBastionSubnet
  - [ ] AzureFirewallSubnet
  - [ ] snet-management

# Spoke VNet
- [ ] Spoke VNet exists: vnet-spoke-demo
- [ ] Spoke subnet created: snet-workload

# On-Prem VNet
- [ ] On-Prem VNet exists: vnet-onprem-demo
- [ ] On-Prem subnets created (2 total):
  - [ ] GatewaySubnet
  - [ ] snet-workload
```

### 3. Verify VPN Gateways
```bash
- [ ] Hub VPN Gateway exists: vpngw-hub-demo
- [ ] Hub gateway status: "Succeeded"
- [ ] Hub gateway public IP assigned
- [ ] On-Prem VPN Gateway exists: vpngw-onprem-demo
- [ ] On-Prem gateway status: "Succeeded"
- [ ] On-Prem gateway public IP assigned
```

### 4. Verify VPN Connections
```bash
- [ ] Hub→OnPrem connection exists: conn-hub-to-onprem
- [ ] Hub→OnPrem connection status: Check (may take 5-10 min)
- [ ] OnPrem→Hub connection exists: conn-onprem-to-hub
- [ ] OnPrem→Hub connection status: Check (may take 5-10 min)

# Note: Connections may show "NotConnected" initially
# This is normal - take 5-10 minutes to stabilize
```

### 5. Verify VNet Peering
```bash
- [ ] Hub→Spoke peering exists: peer-hub-to-spoke
- [ ] Hub→Spoke peering state: "Connected"
- [ ] Spoke→Hub peering exists: peer-spoke-to-hub
- [ ] Spoke→Hub peering state: "Connected"
```

### 6. Verify SQL Server VM
```bash
- [ ] VM exists: vm-sql-demo
- [ ] VM status: "PowerState/running"
- [ ] VM network interface configured
- [ ] Public IP assigned to VM: pip-sql-demo
- [ ] Public IP has valid IP address
- [ ] OS disk created: osdisk-sql-demo
- [ ] Data disk created: datadisk-sql-demo
```

### 7. Verify Network Security Groups
- [ ] NSG exists for hub: nsg-hub-demo
- [ ] NSG exists for spoke: nsg-spoke-demo
- [ ] NSG exists for on-prem: nsg-onprem-demo
- [ ] NSG exists for SQL VM: nsg-sql-vm-demo
- [ ] Rules allow expected traffic:
  - [ ] RDP (3389)
  - [ ] SQL (1433)
  - [ ] VNet traffic

### 8. Test Connectivity - RDP to SQL VM

**Get SQL VM Public IP:**
```bash
SQLIP=$(az network public-ip show \
  -g rg-landing-zone-demo \
  -n pip-sql-demo \
  --query "ipAddress" -o tsv)
echo $SQLIP
```

**Connect via RDP:**
```bash
# Windows
mstsc /v:$SQLIP

# Mac
open "rdp://full%20address=s:$SQLIP:3389&username=s:demoadmin"

# Linux
rdesktop -u demoadmin $SQLIP
```

**After RDP connects:**
- [ ] Windows login successful
- [ ] Username/password accepted
- [ ] Desktop loads
- [ ] No boot errors

### 9. Test SQL Server

**Once RDP connected, verify SQL Server:**
- [ ] SQL Server Management Studio available (Start menu)
- [ ] SQL Server service running (`services.msc`)
- [ ] SQL Server Network Configuration enabled
- [ ] TCP/IP protocol enabled
- [ ] Port 1433 configured

**Connect to SQL Server:**
1. [ ] Open SQL Server Management Studio
2. [ ] Server name: `localhost` or `.`
3. [ ] Authentication: Windows Authentication
4. [ ] Click "Connect"
5. [ ] Object Explorer shows:
   - [ ] Server connection successful
   - [ ] System databases visible (master, msdb, etc.)
   - [ ] User databases visible (if any)

### 10. Test Network Connectivity

**From SQL VM, test other networks:**
```powershell
# Test connectivity to hub
ping 10.0.3.1

# Test connectivity to on-premises
ping 192.168.1.1

# View routing table
route print

# View network configuration
ipconfig /all
```

- [ ] Responses to ping (or expected blocks)
- [ ] Routes show VPN tunnel entries
- [ ] Network configuration shows correct NIC

### 11. Document Deployment Details

Create a deployment record:
```
Deployment Date: [date]
Deployment Time: [duration]
Resource Group: rg-landing-zone-demo
Region: eastus
SQL VM IP: [captured-ip]
Admin Username: demoadmin
Admin Password: [securely-stored]
VPN Status: [Connected/NotConnected]
SQL Connection Status: [Connected/Failed]
Issues Encountered: [none/describe]
Resolution: [if any issues]
```

### 12. Setup Monitoring (Optional)

- [ ] Review Azure Monitor for VM
- [ ] Check resource metrics:
  - [ ] CPU Usage
  - [ ] Memory Available
  - [ ] Network In/Out
- [ ] Setup alerts if needed:
  - [ ] High CPU
  - [ ] Memory pressure
  - [ ] VPN disconnection

### 13. Secure Credentials

- [ ] Admin password stored securely (not in code)
- [ ] VPN shared key not exposed
- [ ] No secrets committed to git
- [ ] Consider Azure Key Vault for production

### 14. Final Verification

- [ ] All resources created successfully
- [ ] Network connectivity verified
- [ ] SQL Server accessible
- [ ] Documentation complete
- [ ] Ready for testing/usage

---

## 🧪 Testing Scenarios

### Scenario 1: Basic Connectivity
- [ ] RDP to SQL VM via public IP
- [ ] Query SQL Server from SSMS
- [ ] Verify network routes

### Scenario 2: Cross-Network Access
- [ ] Deploy VM in on-prem VNet
- [ ] Test communication to hub
- [ ] Test communication to spoke/SQL VM

### Scenario 3: VPN Failover
- [ ] Disable VPN connection
- [ ] Verify routing changes
- [ ] Re-enable VPN connection
- [ ] Verify routing restored

---

## ⚠️ Troubleshooting During Deployment

### If deployment fails:
- [ ] Check error messages in Azure Portal
- [ ] Review Activity Log for details
- [ ] Run template validation again
- [ ] Check quota hasn't been exceeded
- [ ] Verify all parameters are correct

### If you want to retry:
```bash
# Option 1: Delete and redeploy
az group delete -n rg-landing-zone-demo --yes

# Option 2: Incremental deployment (may fail)
az deployment sub create --template-file infra/main.bicep ...
```

### If VPN won't connect:
- [ ] Wait 10 minutes (gateways sometimes need time)
- [ ] Check gateway provisioning state
- [ ] Verify firewall rules
- [ ] Check local network gateway settings
- [ ] Review VPN diagnostics in Portal

---

## 🧹 Post-Usage Cleanup

When finished with testing:

### Stop Resources (to save money)
```bash
# Stop VM (keep gateways for VPN)
az vm deallocate -g rg-landing-zone-demo -n vm-sql-demo

# This reduces costs by ~$35/month
```

### Delete All Resources
```bash
# Permanent deletion
az group delete -g rg-landing-zone-demo --yes

# Verify deletion
az group list --query "[?name=='rg-landing-zone-demo']"
```

---

## 📋 Sign-Off Checklist

- [ ] Deployment completed successfully
- [ ] All resources verified
- [ ] Connectivity tested
- [ ] SQL Server accessible
- [ ] Documentation captured
- [ ] Credentials secured
- [ ] Cost monitoring enabled
- [ ] Ready for use

**Deployment Status:** ✅ COMPLETE

**Date:** ___________
**Validated By:** ___________
**Notes:** ___________

---

## 📞 Support

If issues arise:
1. Review `TROUBLESHOOTING` section in README.md
2. Check Azure Portal Activity Log
3. Run template validation: `az bicep build ...`
4. Verify all prerequisites met
5. Review DEPLOYMENT.md for common issues

---

**Last Updated:** May 5, 2026
