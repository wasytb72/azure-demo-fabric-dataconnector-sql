# Temporary patch script
(Get-Content 'hub-vnet.bicep' -Raw) -replace `
  "(// Public IP for VPN Gateway\r?\nresource publicIp 'Microsoft\.Network/publicIPAddresses@2023-11-01' = \{\r?\n  name: publicIpName\r?\n  location: location\r?\n  sku: \{\r?\n    name: 'Standard'\r?\n    tier: 'Regional'\r?\n  \})\r?\n  (properties:)", `
  "`$1`n  zones: ['1', '2', '3']`n  `$2" | Set-Content 'hub-vnet.bicep'
