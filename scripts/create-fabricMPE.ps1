#az login

$workspaceId = "<workspaceId>"

$bearer_token = az account get-access-token --resource https://api.fabric.microsoft.com

$url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/managedPrivateEndpoints"

$headers = @{
    "Authorization" = "Bearer $($bearer_token.accessToken)"
    "Content-Type"  = "application/json"
}

$body = @{
   name = "onprem-sql-endpoint"
   targetPrivateLinkResourceId = "/subscriptions/<subId>/resourceGroups/<rg>/providers/Microsoft.Network/privateLinkServices/<plsName>"
   targetSubresourceType = "sql"
   targetFQDNs = @("sqlserver.corp.contoso.com")
   requestMessage = "Private connection request from Fabric to on-premises SQL"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body

$response