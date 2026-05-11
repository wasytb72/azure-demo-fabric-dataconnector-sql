#!/bin/bash
set -euo pipefail

# Azure Hub-Spoke Landing Zone Deployment Script (Bash)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Parameters
RESOURCE_GROUP_NAME="${1:-rg-landing-zone-demo}"
LOCATION="${2:-eastus}"
ADMIN_PASSWORD="${3:-}"
ENVIRONMENT="${4:-demo}"
SKIP_VALIDATION="${5:-false}"
FABRIC_CAPACITY_ADMINS_RAW="${6:-}"

# Build a valid JSON array from a comma-separated list of admins.
# Example input: "user1@contoso.com,user2@contoso.com"
function build_json_array_from_csv() {
    local csv="$1"
    if [[ -z "${csv// /}" ]]; then
        echo "[]"
        return 0
    fi

    local json="["
    IFS=',' read -r -a items <<< "$csv"
    for item in "${items[@]}"; do
        # Trim whitespace
        item="$(echo "$item" | xargs)"
        if [[ -z "$item" ]]; then
            continue
        fi

        # Escape JSON special chars minimally for email-like identities
        item="${item//\\/\\\\}"
        item="${item//\"/\\\"}"

        if [[ "$json" != "[" ]]; then
            json+=","
        fi
        json+="\"$item\""
    done
    json+="]"

    echo "$json"
}

FABRIC_CAPACITY_ADMINS_JSON="$(build_json_array_from_csv "$FABRIC_CAPACITY_ADMINS_RAW")"

function print_status() {
    local message="$1"
    local status="${2:-info}"
    local timestamp=$(date '+%H:%M:%S')
    
    case $status in
        success)
            echo -e "${GREEN}[${timestamp}] ✓ ${message}${NC}"
            ;;
        error)
            echo -e "${RED}[${timestamp}] ✗ ${message}${NC}"
            ;;
        warning)
            echo -e "${YELLOW}[${timestamp}] ⚠ ${message}${NC}"
            ;;
        info)
            echo -e "${BLUE}[${timestamp}] ℹ ${message}${NC}"
            ;;
    esac
}

function test_prerequisites() {
    print_status "Checking prerequisites..." "info"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_status "Azure CLI not found. Install from https://aka.ms/azure-cli" "error"
        return 1
    fi
    print_status "Azure CLI found: $(az --version 2>&1 | head -1)" "success"
    
    # Check authentication
    if ! az account show &> /dev/null; then
        print_status "Not authenticated. Run 'az login'" "error"
        return 1
    fi
    print_status "Authenticated to Azure" "success"
    
    # Check template file
    if [[ ! -f "infra/main.bicep" ]]; then
        print_status "infra/main.bicep not found" "error"
        return 1
    fi
    print_status "Template file found" "success"
    
    return 0
}

function test_template_validation() {
    print_status "Validating Bicep template..." "info"
    
    # Build Bicep
    if ! az bicep build --file infra/main.bicep > /dev/null 2>&1; then
        print_status "Bicep compilation failed" "error"
        return 1
    fi
    print_status "Bicep template compiled successfully" "success"
    
    # Validate template
    if ! az deployment sub validate \
        --location "$LOCATION" \
        --template-file infra/main.bicep \
        --parameters \
            resourceGroupName="$RESOURCE_GROUP_NAME" \
            location="$LOCATION" \
            adminPassword="$ADMIN_PASSWORD" \
            environment="$ENVIRONMENT" \
            fabricCapacityAdmins="$FABRIC_CAPACITY_ADMINS_JSON" \
        > /dev/null 2>&1; then
        print_status "Template validation failed" "error"
        return 1
    fi
    print_status "Template validation passed" "success"
    
    return 0
}

function test_quotas() {
    print_status "Checking resource quotas..." "info"
    
    # Check VM quota (basic check)
    VM_USAGE=$(az vm list-usage --location "$LOCATION" --query "[?name.value=='standardBSFamily'].currentValue" -o tsv 2>/dev/null || echo "0")
    VM_LIMIT=$(az vm list-usage --location "$LOCATION" --query "[?name.value=='standardBSFamily'].limit" -o tsv 2>/dev/null || echo "10")
    
    if (( VM_USAGE >= VM_LIMIT - 1 )); then
        print_status "Low VM quota: $VM_USAGE/$VM_LIMIT" "warning"
        return 1
    fi
    print_status "VM quota available: $VM_USAGE/$VM_LIMIT" "success"
    
    return 0
}

function start_deployment() {
    local deployment_name="hub-spoke-$(date +%Y%m%d-%H%M%S)"
    
    print_status "Starting deployment of $RESOURCE_GROUP_NAME to $LOCATION..." "info"
    
    if ! az deployment sub create \
        --location "$LOCATION" \
        --name "$deployment_name" \
        --template-file infra/main.bicep \
        --parameters \
            resourceGroupName="$RESOURCE_GROUP_NAME" \
            location="$LOCATION" \
            environment="$ENVIRONMENT" \
            adminPassword="$ADMIN_PASSWORD" \
            fabricCapacityAdmins="$FABRIC_CAPACITY_ADMINS_JSON" \
        > /dev/null 2>&1; then
        print_status "Deployment failed" "error"
        return 1
    fi
    
    print_status "Deployment initiated: $deployment_name" "success"
    echo "$deployment_name"
    return 0
}

function wait_deployment() {
    local deployment_name="$1"
    local max_wait=1800  # 30 minutes
    local interval=30    # Check every 30 seconds
    local elapsed=0
    
    print_status "Waiting for deployment to complete (this may take 25-30 minutes)..." "info"
    
    while (( elapsed < max_wait )); do
        local status=$(az deployment sub show --name "$deployment_name" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "")
        
        print_status "Deployment status: $status" "info"
        
        if [[ "$status" == "Succeeded" ]]; then
            print_status "Deployment completed successfully!" "success"
            return 0
        elif [[ "$status" == "Failed" ]]; then
            print_status "Deployment failed" "error"
            return 1
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        printf "."
    done
    
    echo ""
    print_status "Deployment timeout - check Azure Portal for status" "warning"
    return 1
}

function show_outputs() {
    local deployment_name="$1"
    
    print_status "Retrieving deployment outputs..." "info"
    
    local outputs=$(az deployment sub show --name "$deployment_name" --query "properties.outputs" -o json)
    
    echo ""
    print_status "=== DEPLOYMENT OUTPUTS ===" "success"
    echo ""
    
    echo "Hub VNet ID: $(echo "$outputs" | jq -r '.hubVNetId.value')"
    echo "Spoke VNet ID: $(echo "$outputs" | jq -r '.spokeVNetId.value')"
    echo "On-Prem VNet ID: $(echo "$outputs" | jq -r '.onPremVNetId.value')"
    echo ""
    echo -e "${BLUE}SQL Server VM ID:${NC} $(echo "$outputs" | jq -r '.sqlVmId.value')"
    echo -e "${BLUE}SQL Server VM Name:${NC} $(echo "$outputs" | jq -r '.sqlVmName.value')"
    echo -e "${YELLOW}SQL Server Public IP:${NC} $(echo "$outputs" | jq -r '.sqlVmPublicIp.value')"
    echo -e "${YELLOW}SQL Connection String:${NC} $(echo "$outputs" | jq -r '.sqlConnectionString.value'),1433"
    echo ""
    
    print_status "Next steps:" "info"
    echo "  1. RDP to VM: $(echo "$outputs" | jq -r '.sqlVmPublicIp.value')"
    echo "  2. Username: demoadmin"
    echo "  3. Password: Check your input"
    echo "  4. Open SQL Server Management Studio"
    echo "  5. Connect to: localhost,1433"
    echo ""
}

function show_resources() {
    local resource_group="$1"
    
    print_status "Resource group created:" "success"
    
    az resource list \
        --resource-group "$resource_group" \
        --query "[].{Name:name, Type:type, Location:location}" \
        -o table
}

# Validation
if [[ -z "$ADMIN_PASSWORD" ]]; then
    read -sp "Enter admin password for Windows VM: " ADMIN_PASSWORD
    echo
fi

# Main
echo ""
print_status "╔════════════════════════════════════════════════════════════╗" "info"
print_status "║     Azure Hub-Spoke Landing Zone Deployment Script         ║" "info"
print_status "╚════════════════════════════════════════════════════════════╝" "info"
echo ""

# Prerequisites
if ! test_prerequisites; then
    exit 1
fi

echo ""

# Validation
if [[ "$SKIP_VALIDATION" != "true" ]]; then
    if ! test_template_validation; then
        exit 1
    fi
    
    echo ""
    
    if ! test_quotas; then
        read -p "Continue anyway? (yes/no): " continue_choice
        if [[ "$continue_choice" != "yes" ]]; then
            exit 1
        fi
    fi
fi

echo ""
echo "Deployment Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Location: $LOCATION"
echo "  Environment: $ENVIRONMENT"
echo "  Fabric Capacity Admins (JSON): $FABRIC_CAPACITY_ADMINS_JSON"
echo ""

# Confirmation
read -p "Proceed with deployment? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    print_status "Deployment cancelled" "warning"
    exit 0
fi

echo ""

# Deployment
DEPLOYMENT_NAME=$(start_deployment)
if [[ -z "$DEPLOYMENT_NAME" ]]; then
    exit 1
fi

echo ""
wait_deployment "$DEPLOYMENT_NAME"

echo ""
show_outputs "$DEPLOYMENT_NAME"

echo ""
show_resources "$RESOURCE_GROUP_NAME"

echo ""
print_status "Deployment script completed!" "success"
echo ""
