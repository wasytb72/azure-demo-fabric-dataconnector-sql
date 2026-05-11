#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys the Azure Hub-Spoke Landing Zone with VPN and SQL Server

.DESCRIPTION
    This script validates and deploys the complete hub-spoke architecture
    including networking, VPN, and SQL Server VM.

.PARAMETER ResourceGroupName
    Name of the resource group to create

.PARAMETER Location
    Azure region for deployment

.PARAMETER AdminPassword
    Admin password for Windows VM (must be complex)

.PARAMETER Environment
    Environment name (default: demo)

.PARAMETER fabricCapacityAdmins
    Array of user principal names to be added as admins to the Fabric Capacity

.EXAMPLE
    .\deploy.ps1 -AdminPassword "P@ssw0rd123!"
    
.EXAMPLE
    .\deploy.ps1 -ResourceGroupName "rg-prod-landing" -Location "westus" -AdminPassword "SecureP@ss123"

.EXAMPLE
    .\deploy.ps1 -ResourceGroupName "rg-prod-landing" -Location "westus" -AdminPassword "SecureP@ss123"-fabricCapacityAdmins @("dawahby@microsoft.com")
#>

param(
    [string]$ResourceGroupName = "rg-landing-zone-demo",
    [string]$Location = "swedencentral",
    [Parameter(Mandatory=$true)][string]$AdminPassword,
    [string]$Environment = "demo",
    [switch]$SkipValidation,
    [switch]$WhatIf,
    [switch]$AutoApprove,
    [array]$fabricCapacityAdmins = @(),
    [switch]$DeployFabric
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# Serialize array parameters once so Azure CLI receives valid JSON values.
# -AsArray ensures a single admin is emitted as ["user@contoso.com"], not "user@contoso.com".
$fabricCapacityAdminsJson = @($fabricCapacityAdmins) | ConvertTo-Json -Compress -AsArray

function New-DeploymentParametersFile {
    $paramsPayload = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            resourceGroupName = @{ value = $ResourceGroupName }
            location = @{ value = $Location }
            environment = @{ value = $Environment }
            adminPassword = @{ value = $AdminPassword }
            fabricCapacityAdmins = @{ value = @($fabricCapacityAdmins) }
            deployFabric = @{ value = $DeployFabric.IsPresent }
        }
    }

    $paramsFilePath = Join-Path $env:TEMP ("hub-spoke-params-" + [Guid]::NewGuid().ToString() + ".json")
    $paramsPayload | ConvertTo-Json -Depth 20 | Set-Content -Path $paramsFilePath -Encoding UTF8
    return $paramsFilePath
}

# Colors for output
$colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
}

function Write-Status {
    param([string]$Message, [string]$Status = "Info")
    $color = $colors[$Status]
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline
    Write-Host $Message -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Status "Checking prerequisites..." "Info"
    
    # Check Azure CLI
    try {
        $azVersion = az --version 2>&1 | Select-Object -First 1
        Write-Status "✓ Azure CLI: $azVersion" "Success"
    }
    catch {
        Write-Status "✗ Azure CLI not found. Install from https://aka.ms/azure-cli" "Error"
        return $false
    }
    
    # Check authentication
    try {
        $account = az account show 2>&1
        if ($?) {
            Write-Status "✓ Authenticated to Azure" "Success"
        }
    }
    catch {
        Write-Status "✗ Not authenticated. Run 'az login'" "Error"
        return $false
    }
    
    # Check template file
    if (-not (Test-Path "infra/main.bicep")) {
        Write-Status "✗ infra/main.bicep not found" "Error"
        return $false
    }
    Write-Status "✓ Template file found" "Success"
    
    return $true
}

function Test-TemplateValidation {
    Write-Status "Validating Bicep template..." "Info"
    
    # Build Bicep
    try {
        az bicep build --file infra/main.bicep | Out-Null
        Write-Status "✓ Bicep template compiled successfully" "Success"
    }
    catch {
        Write-Status "✗ Bicep compilation failed: $_" "Error"
        return $false
    }
    
    # Validate template
    $paramsFile = New-DeploymentParametersFile
    try {
        $validation = az deployment sub validate `
            --name "validate-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            --location $Location `
            --template-file infra/main.bicep `
            --parameters "@$paramsFile" `
            --output json 2>&1
        
        if ($?) {
            Write-Status "✓ Template validation passed" "Success"
            return $true
        }
        else {
            Write-Status "✗ Template validation failed: $validation" "Error"
            return $false
        }
    }
    catch {
        Write-Status "✗ Validation error: $_" "Error"
        return $false
    }
    finally {
        if (Test-Path $paramsFile) {
            Remove-Item $paramsFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-Quotas {
    Write-Status "Checking resource quotas..." "Info"
    
    # Check VM quota
    $vmUsage = az vm list-usage --location $Location --query "[?name.value=='standardBSFamily'].{Current:currentValue,Limit:limit}" -o json | ConvertFrom-Json
    
    if ($vmUsage.Current -ge $vmUsage.Limit - 1) {
        Write-Status "⚠ Low VM quota: $($vmUsage.Current)/$($vmUsage.Limit)" "Warning"
        return $false
    }
    Write-Status "✓ VM quota available: $($vmUsage.Current)/$($vmUsage.Limit)" "Success"
    
    return $true
}

function Start-Deployment {
    Write-Status "Starting deployment of $ResourceGroupName to $Location..." "Info"
    
    $deploymentName = "hub-spoke-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $paramsFile = New-DeploymentParametersFile

    try {
        if ($WhatIf) {
            Write-Status "Running in What-If mode (no resources will be created)..." "Warning"
            az deployment sub what-if `
                --location $Location `
                --name $deploymentName `
                --template-file infra/main.bicep `
                --parameters "@$paramsFile" `
                --output json | Out-Null
        }
        else {
            az deployment sub create `
                --location $Location `
                --name $deploymentName `
                --template-file infra/main.bicep `
                --parameters "@$paramsFile" `
                --output json | Out-Null
        }

        Write-Status "Deployment initiated: $deploymentName" "Success"
        return $deploymentName
    }
    catch {
        Write-Status "Deployment failed: $_" "Error"
        return $null
    }
    finally {
        if (Test-Path $paramsFile) {
            Remove-Item $paramsFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Wait-Deployment {
    param([string]$DeploymentName)
    
    Write-Status "Waiting for deployment to complete (this may take 60-90 minutes with VPN + Firewall)..." "Info"
    
    $maxWait = 5400  # 90 minutes
    $interval = 30   # Check every 30 seconds
    $elapsed = 0
    
    while ($elapsed -lt $maxWait) {
        try {
            $deployment = az deployment sub show --name $DeploymentName --query "properties.provisioningState" -o tsv
            
            Write-Status "Deployment status: $deployment" "Info"
            
            if ($deployment -eq "Succeeded") {
                Write-Status "✓ Deployment completed successfully!" "Success"
                return $true
            }
            elseif ($deployment -eq "Failed") {
                Write-Status "✗ Deployment failed" "Error"
                return $false
            }
        }
        catch {
            # Ignore errors during polling
        }
        
        Start-Sleep -Seconds $interval
        $elapsed += $interval
        $percent = [math]::Min(100, ($elapsed / $maxWait * 100))
        Write-Host "." -NoNewline -ForegroundColor $colors.Info
    }
    
    Write-Host ""
    Write-Status "Deployment timeout - check Azure Portal for status" "Warning"
    return $false
}

function Show-Outputs {
    param([string]$DeploymentName)
    
    Write-Status "Retrieving deployment outputs..." "Info"
    
    try {
        $outputs = az deployment sub show `
            --name $DeploymentName `
            --query "properties.outputs" `
            -o json | ConvertFrom-Json
        
        Write-Host ""
        Write-Status "=== DEPLOYMENT OUTPUTS ===" "Success"
        Write-Host ""
        
        Write-Host "Hub VNet ID: $($outputs.hubVNetId.value)"
        Write-Host "Spoke VNet ID: $($outputs.spokeVNetId.value)"
        Write-Host "On-Prem VNet ID: $($outputs.onPremVNetId.value)"
        Write-Host ""
        Write-Host "SQL Server VM ID: $($outputs.sqlVmId.value)" -ForegroundColor Cyan
        Write-Host "SQL Server VM Name: $($outputs.sqlVmName.value)" -ForegroundColor Cyan
        Write-Host "SQL Server Public IP: $($outputs.sqlVmPublicIp.value)" -ForegroundColor Yellow
        Write-Host "SQL Connection String: $($outputs.sqlConnectionString.value),1433" -ForegroundColor Yellow
        Write-Host ""
        
        Write-Status "Next steps:" "Info"
        Write-Host "  1. RDP to VM: $($outputs.sqlVmPublicIp.value)"
        Write-Host "  2. Username: demoadmin"
        Write-Host "  3. Password: Check your input"
        Write-Host "  4. Open SQL Server Management Studio"
        Write-Host "  5. Connect to: localhost,1433"
        Write-Host ""
    }
    catch {
        Write-Status "Could not retrieve outputs: $_" "Warning"
    }
}

function Show-Resources {
    param([string]$ResourceGroupName)
    
    Write-Status "Resource group created:" "Success"
    
    $resources = az resource list `
        --resource-group $ResourceGroupName `
        --query "[].{Name:name, Type:type, Location:location}" `
        -o table
    
    Write-Host $resources
}

# Main execution
function Main {
    Write-Host ""
    Write-Status "╔════════════════════════════════════════════════════════════╗" "Info"
    Write-Status "║     Azure Hub-Spoke Landing Zone Deployment Script         ║" "Info"
    Write-Status "╚════════════════════════════════════════════════════════════╝" "Info"
    Write-Host ""
    
    # Prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    Write-Host ""
    
    # Validation
    if (-not $SkipValidation) {
        if (-not (Test-TemplateValidation)) {
            exit 1
        }
        
        Write-Host ""
        
        if (-not (Test-Quotas)) {
            Write-Status "Continue anyway?" "Warning"
            $continue = Read-Host "Enter 'yes' to continue"
            if ($continue -ne "yes") {
                exit 1
            }
        }
    }
    
    Write-Host ""
    Write-Host "Deployment Configuration:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroupName"
    Write-Host "  Location: $Location"
    Write-Host "  Environment: $Environment"
    Write-Host "  Fabric Capacity Admins: $fabricCapacityAdminsJson"
    Write-Host "  Deploy Fabric: $($DeployFabric.IsPresent)"
    Write-Host ""
    
    if ($WhatIf) {
        Write-Host "What-If Mode: Changes will NOT be applied" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Confirmation
    if (-not $AutoApprove) {
        $confirm = Read-Host "Proceed with deployment? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Status "Deployment cancelled" "Warning"
            exit 0
        }
    }
    else {
        Write-Status "Auto-approve enabled, continuing without prompt." "Info"
    }
    
    Write-Host ""
    
    # Deployment
    $deploymentName = Start-Deployment
    if (-not $deploymentName) {
        exit 1
    }
    
    if (-not $WhatIf) {
        Write-Host ""
        Wait-Deployment $deploymentName
        
        Write-Host ""
        Show-Outputs $deploymentName
        
        Write-Host ""
        Show-Resources $ResourceGroupName
    }
    
    Write-Host ""
    Write-Status "Deployment script completed!" "Success"
    Write-Host ""
}

# Run main
Main
