# Architecture & Configuration Guide

## Network Architecture Details

### Hub VNet (10.0.0.0/16)

```
Hub VNet: 10.0.0.0/16
├── GatewaySubnet: 10.0.0.0/24
│   └── VPN Gateway (RouteBased, VpnGw2)
├── AzureBastionSubnet: 10.0.1.0/24
│   └── Reserved for Azure Bastion (future enhancement)
├── AzureFirewallSubnet: 10.0.2.0/24
│   └── Reserved for Azure Firewall (future enhancement)
└── Management Subnet: 10.0.3.0/24
    └── For management VMs/bastion hosts
```

**Features:**
- Central hub for all network traffic
- VPN Gateway for hybrid connectivity
- Supports gateway transit (allows spoke VMs to access on-premises)
- Reserved subnets for future security enhancements

### Spoke VNet (10.1.0.0/16)

```
Spoke VNet: 10.1.0.0/16
└── snet-workload: 10.1.0.0/24
    └── SQL Server VM
        ├── Private IP: Dynamic (10.1.0.x)
        ├── Public IP: Assigned
        └── NSG Rules:
            ├── Allow RDP (3389) from anywhere
            ├── Allow SQL (1433) from VNet
            └── Allow inbound VNet traffic
```

**Features:**
- Isolated workload subnet
- Connected to hub via VNet peering
- Uses hub's VPN gateway for on-premises access
- Network Security Group for ingress filtering

### On-Premises Simulation VNet (192.168.0.0/16)

```
On-Prem VNet: 192.168.0.0/16
├── GatewaySubnet: 192.168.0.0/24
│   └── VPN Gateway (RouteBased, VpnGw2)
└── snet-workload: 192.168.1.0/24
    └── On-premises workload VMs (simulated)
```

**Features:**
- Represents on-premises infrastructure
- Connected to hub via Site-to-Site VPN
- Separate address space to prevent IP overlap
- VPN Gateway for site-to-site connectivity

## VPN Configuration

### Site-to-Site VPN Tunnel

```
┌─────────────────────┐                    ┌──────────────────────┐
│   Hub VPN Gateway   │                    │ On-Prem VPN Gateway  │
│   PIP: <dynamic>    │◄───────IKEv2───────►│   PIP: <dynamic>     │
│   192.168.0.0/16    │  Shared Key Auth   │   10.0.0.0/16        │
└─────────────────────┘                    └──────────────────────┘
        ↓                                           ↓
    Hub VNet                              On-Prem VNet
  Traffic Rules:                        Traffic Rules:
  - Allow IKEv2 (UDP 500)               - Allow IKEv2 (UDP 500)
  - Allow IPSec (UDP 4500)              - Allow IPSec (UDP 4500)
  - Allow traffic to 192.168.0.0/16     - Allow traffic to 10.0.0.0/16
```

**VPN Settings:**
- Protocol: IKEv2 (more reliable than IKEv1)
- Encryption: AES256 (Azure default)
- Integrity: SHA256
- DH Group: DHGroup14
- IPSec Lifetime: 28800 seconds
- Shared Key: P@ssw0rdDemo123! (demo-only; use Key Vault in production)

### Connection Status Monitoring

```bash
# View connection status
az network vpn-connection show \
  --resource-group rg-landing-zone-demo \
  --name conn-hub-to-onprem \
  --query "{
    Name:name,
    Status:connectionStatus,
    Type:connectionType,
    Location:location
  }"

# Expected output:
# "Status": "Connected" or "NotConnected"
# "Type": "IPsec"
```

## Network Peering Configuration

### Hub-to-Spoke Peering

```
Peering: peer-hub-to-spoke
├── AllowVirtualNetworkAccess: true
├── AllowForwardedTraffic: true
├── AllowGatewayTransit: true ← Allows spoke to use hub's VPN gateway
└── UseRemoteGateways: false
```

**Impact:**
- Hub can reach all spoke resources
- Hub can forward traffic from on-premises to spoke
- Spoke VMs can communicate with on-premises via hub gateway

### Spoke-to-Hub Peering

```
Peering: peer-spoke-to-hub
├── AllowVirtualNetworkAccess: true
├── AllowForwardedTraffic: true
├── AllowGatewayTransit: false
└── UseRemoteGateways: true ← Uses hub's VPN gateway for on-premises access
```

**Impact:**
- Spoke can reach all hub resources
- Spoke can reach on-premises via hub's VPN gateway
- Spoke VMs route on-premises traffic through hub

## Routing

### Effective Routes on SQL Server VM

```
Route Priority | Destination          | Next Hop         | Learned Via
1              | 10.1.0.0/24         | On-Nic          | System
2              | 10.0.0.0/16         | VNetPeering     | Peering
3              | 192.168.0.0/16      | VPN Gateway     | Gateway Transit
4              | 0.0.0.0/0           | Internet        | System
```

**Traffic Flow Examples:**

1. **SQL VM → Hub Management Subnet**
   - Destination: 10.0.3.0/24
   - Route: VNet Peering → Hub VNet → Direct delivery
   - Latency: ~1-3ms

2. **SQL VM → On-Premises**
   - Destination: 192.168.1.0/24
   - Route: Gateway Transit → Hub VPN Gateway → VPN Tunnel
   - Latency: ~20-50ms (depends on VPN stability)

3. **SQL VM → Internet**
   - Destination: Any external IP
   - Route: Direct to Internet (SNAT via VM public IP)
   - Latency: Depends on ISP

## SQL Server Configuration

### Pre-Installed Components
- Windows Server 2022 Datacenter
- SQL Server 2022 Web Edition
- SQL Server Management Tools
- Windows Firewall enabled
- Windows Defender running

### SQL Server Services

```
Service Name                   | Port | Status
SQL Server (MSSQLSERVER)      | 1433 | Running
SQL Server Agent (SQLSERVERAGENT) | N/A | Manual
SQL Server Browser            | 1434 | Manual
SQL Server Full Text Search   | N/A  | Manual
```

### Accessing SQL Server

**From Within Azure (Recommended):**
```sql
-- Connection String for SSMS:
10.1.0.x,1433

-- Windows Authentication (domain-joined):
Windows Authentication

-- From Command Line:
sqlcmd -S 10.1.0.x,1433 -U demoadmin -P "P@ssw0rdDemo123!"
```

**From On-Premises (via VPN):**
```sql
-- Connection String (after VPN established):
10.1.0.x,1433

-- Uses VPN tunnel for secure connection
-- Latency: 20-50ms over VPN
```

**From Internet (Not Recommended for Production):**
```sql
-- Connection String (public IP):
<PublicIP>,1433

-- Security Risk: Exposed to internet
-- Use Azure Firewall or NSG rules in production
```

### SQL Server Network Configuration

```
Protocol    | Enabled | Port | Named Pipes
TCP/IP      | Yes     | 1433 | No
Named Pipes | Yes     | N/A  | \\MSSQLSERVER
Shared Mem  | Yes     | N/A  | (local)
```

## Security Best Practices

### Network Security

1. **NSG Rules** (Current State)
   - RDP (3389): Open to all (OK for demo, restrict in production)
   - SQL (1433): Open to all (SHOULD BE RESTRICTED)
   - VNet: Open for internal communication

2. **Improvements for Production**
   ```bash
   # Restrict SQL Server access to VNet only
   az network nsg rule create \
     --resource-group rg-landing-zone-demo \
     --nsg-name nsg-sql-vm-demo \
     --name AllowSQL_VNetOnly \
     --priority 101 \
     --source-address-prefixes VirtualNetwork \
     --destination-port-ranges 1433 \
     --access Allow \
     --protocol Tcp

   # Remove public access
   az network nsg rule delete \
     --resource-group rg-landing-zone-demo \
     --nsg-name nsg-sql-vm-demo \
     --name AllowSQL
   ```

### VPN Security

1. **Current Configuration**
   - Shared key in parameters (demo-only)
   - No BGP (static routes only)
   - No DPD (Dead Peer Detection)

2. **Production Hardening**
   ```bash
   # Store shared key in Key Vault
   az keyvault secret set \
     --vault-name kv-prod \
     --name vpn-shared-key \
     --value "ComplexSecureKey123!@#"

   # Enable BGP
   az network vpn-connection update \
     --resource-group rg-landing-zone-demo \
     --name conn-hub-to-onprem \
     --enable-bgp
   ```

### SQL Server Security

1. **Enable SQL Authentication**
   ```sql
   -- On SQL Server VM
   -- Enable Mixed Mode in SQL Server Configuration Manager
   -- Restart SQL Server service
   ```

2. **Create Restricted Accounts**
   ```sql
   -- Create application account
   CREATE LOGIN app_user WITH PASSWORD = 'ComplexP@ssw0rd123'
   CREATE USER app_user FOR LOGIN app_user
   GRANT SELECT, INSERT, UPDATE ON <database> TO app_user
   ```

3. **Enable Encryption**
   ```sql
   -- Force Encryption in SQL Server Configuration Manager
   -- Certificate-based TLS 1.2+
   ```

## Monitoring & Diagnostics

### View VPN Diagnostics
```bash
# Connection logs
az monitor activity-log list \
  --resource-group rg-landing-zone-demo \
  --resource-provider Microsoft.Network \
  --resource-type virtualNetworkGateways

# VPN Gateway metrics
az monitor metrics list-definitions \
  --resource-type "Microsoft.Network/virtualNetworkGateways" \
  --namespace "Microsoft.Network/virtualNetworkGateways"
```

### Monitor SQL Server
```powershell
# RDP to VM, then:

# CPU Usage
Get-Counter -Counter "\Processor(_Total)\% Processor Time"

# Memory
Get-Counter -Counter "\Memory\Available MBytes"

# SQL Server Connections
SELECT COUNT(*) as ActiveConnections 
FROM sys.dm_exec_sessions

# Long-Running Queries
SELECT * FROM sys.dm_exec_requests
WHERE session_id > 50
```

## File Storage

### Data Disk Configuration

```
Disk          | Size | Type       | Caching | Purpose
OS Disk       | 128G | Premium    | ReadWrite | Windows + SQL binaries
Data Disk     | 128G | Premium    | ReadWrite | Database files
```

### Recommended Database Placement

```powershell
# On VM (after RDP):
# Format data disk and mount to D:\

# Optimal placement:
D:\
├── Data Files (*.mdf)
├── Log Files (*.ldf)
└── TempDB (*.mdf, *.ldf)

# DO NOT place on C:\ (OS drive)
```

## Cost Optimization

### Current Configuration Costs

| Component | Quantity | Monthly Cost |
|-----------|----------|--------------|
| VPN Gateway (VpnGw2) | 2 | $95 each = $190 |
| Standard_B2s VM | 1 | $35 |
| Premium SSD (128GB) | 2 | $15 each = $30 |
| Public IPs | 3 | $5 each = $15 |
| Data Transfer | Minimal | $0-5 |
| **Total** | | **~$270** |

### Cost Reduction Options

1. **Reduce VPN Gateway SKU** (Not recommended for production)
   ```
   VpnGw1 (half the cost but reduced throughput)
   ```

2. **Use Smaller VM**
   ```
   Standard_B1s: $6/month instead of $35 (8x cheaper)
   Trade-off: Limited SQL workload capacity
   ```

3. **Use Spot VMs** (if workload allows)
   ```
   Up to 90% savings but can be interrupted
   ```

4. **Stop resources when not in use**
   ```bash
   # Stop VM (keep gateways for VPN readiness)
   az vm deallocate --resource-group rg-landing-zone-demo \
     --name vm-sql-demo
   ```

---

**Last Updated**: May 5, 2026
