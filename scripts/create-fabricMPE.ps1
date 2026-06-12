#az login

param(
    [Parameter(Mandatory=$true)]
    [string]$workspaceId,
    [Parameter(Mandatory=$true)]
    [string]$subscriptionId,
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$plsName,
    [Parameter(Mandatory=$false)]
    [string]$targetSubresourceType = "sql"
)
# $workspaceId = "<workspaceId>"
$subId = $subscriptionId
$rg = $resourceGroupName


$accessToken = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv

if (-not $accessToken) {
    throw "Failed to acquire Fabric access token. Run 'az login' and ensure you have access to the Fabric workspace."
}

$url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/managedPrivateEndpoints"

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
}

$body = @{
    name = "onprem-sql-endpoint"
    targetPrivateLinkResourceId = "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Network/privateLinkServices/$plsName"
    targetSubResourceId = "sql"
    targetFQDNs = @("sqlserver-demo.corp.contoso.com")
    requestMessage = "Private connection request from Fabric to on-premises SQL"
} | ConvertTo-Json

Write-Verbose "Request body: $body"

try {
    $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body
    $response
}
catch {
    $statusCode = $null
    $responseBody = $null
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $responseBody = $reader.ReadToEnd()
            }
        }
        catch {
            # Ignore response body parsing failures
        }
    }

    if ($responseBody) {
        Write-Error "Fabric API request failed. StatusCode: $statusCode. Body: $responseBody"
    }
    else {
        Write-Error "Fabric API request failed. StatusCode: $statusCode. $_"
    }

    if ($statusCode -eq 404) {
        Write-Warning "Workspace not found. Ensure -workspaceId is the Fabric workspace GUID (not capacity ID)."
    }

    throw
}