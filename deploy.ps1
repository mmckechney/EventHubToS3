param(
    [string]
    $resourceGroupName,
    [string]
    $location,
    [string]
    $functionAppName,
    [bool]
    $deployResources = $true
)

$functionAppNameElastic = "$($functionAppName)elastic"
Write-Host "Creating Resource Group $resourceGroupName" -ForegroundColor Cyan
az group create --name $resourceGroupName --location $location -o table

Write-Host "Creating Demo Function App and demo resources" -ForegroundColor Cyan
if($deployResources)
{
    az deployment group create -g $resourceGroupName --template-file azuredeploy.bicep --parameters functionAppName="$functionAppName" functionAppNameElastic="$functionAppNameElastic" -o table
}

#Add Connection string to key vault
$keyVaultName = az keyvault list --resource-group $resourceGroupName -o tsv --query "[].name"

Write-Host "Setting current user Key Vault Access Policy" -ForegroundColor Cyan
$currentUser = az account show -o tsv --query "user.name"
$currentUserObjectId = az ad user show --id $currentUser -o tsv --query objectId
az keyvault set-policy --name $keyVaultName --object-id $currentUserObjectId --secret-permissions set list -o table

Write-Host "Adding connection strings to Key Vault" -ForegroundColor Cyan
# Get EventHub Connection string
$eventhubNamespaceName = az eventhubs namespace list --resource-group $resourceGroupName -o tsv --query '[].name'
$eventHubAuthRuleName = az eventhubs namespace authorization-rule list  --resource-group $resourceGroupName --namespace-name $eventhubNamespaceName  -o tsv --query [].name
$eventHubConnectionString = az eventhubs namespace authorization-rule keys list --resource-group $resourceGroupName --namespace-name $eventHubNamespaceName --name $eventHubAuthRuleName -o tsv --query "primaryConnectionString"
$eventHubName = az eventhubs eventhub list --resource-group $resourceGroupName --namespace-name $eventhubNamespaceName -o tsv --query [].name

# Get Storage Connection string
$storageAccountName = az storage account list --resource-group $resourceGroupName -o tsv --query [].name
$storageConnectionString = az storage account show-connection-string --name $storageAccountName --resource-group $resourceGroupName -o tsv



Write-Host "Adding EventHubConnectionString to $keyVaultName" -ForegroundColor Cyan
az keyvault secret set --value $eventHubConnectionString --vault-name $keyVaultName --name "EventHubConnectionString" -o tsv --query "name"

# Write-Host "Adding Storage Account connection string  to $keyVaultName" -ForegroundColor Cyan
# az keyvault secret set --value $storageConnectionString --vault-name $keyVaultName --name "AzureWebJobsStorage" -o tsv --query "name"


Write-Host "Adding dummy key vault secrets for S3 values. Be sure to change these!" -ForegroundColor Cyan
$tmpVal = az keyvault secret list --vault-name $keyVaultName -o tsv  --query "[?contains(@.name 'S3Secret')].name"
if([string]::IsNullOrEmpty($tmpVal))
{
    az keyvault secret set --value "CHANGE ME" --vault-name $keyVaultName --name "S3Secret" -o tsv --query "name"
}
else {
    Write-Host "Skipping S3Secret - already exists"
}
$tmpVal =az keyvault secret list --vault-name $keyVaultName -o tsv  --query "[?contains(@.name 'S3AccessKey')].name"
if([string]::IsNullOrEmpty($tmpVal))
{
    az keyvault secret set --value "CHANGE ME" --vault-name $keyVaultName --name "S3AccessKey" -o tsv --query "name"
}
else {
    Write-Host "Skipping S3AccessKey - already exists"
}
$tmpVal = az keyvault secret list --vault-name $keyVaultName -o tsv  --query "[?contains(@.name 'S3BucketName')].name"
if([string]::IsNullOrEmpty($tmpVal))
{
    az keyvault secret set --value "CHANGE ME" --vault-name $keyVaultName --name "S3BucketName" -o tsv --query "name"
}
else {
    Write-Host "Skipping S3BucketName - already exists"
}

Write-Host "Building Function App " -ForegroundColor Cyan
dotnet publish .\EventHubToS3\EventHubToS3.csproj

$publishFolder = [IO.Path]::GetFullPath("EventHubToS3\bin\Debug\net6.0\publish")
$publishZip = [IO.Path]::GetFullPath("publish.zip")
if(Test-path $publishZip) {Remove-item $publishZip}
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($publishFolder, $publishZip)

Write-Host "Deploying Consumption Plan Function App to Azure " -ForegroundColor Cyan
az functionapp deploy --resource-group  $resourceGroupName --name $functionAppName --src-path $publishZip --type zip --async true -o table

Write-Host "Deploying Premium Elastic Plan Function App to Azure " -ForegroundColor Cyan
az functionapp deploy --resource-group  $resourceGroupName --name $functionAppNameElastic --src-path $publishZip --type zip --async true -o table

Write-Host "Settings Function App - AppSettings to Key Vault References " -ForegroundColor Cyan
$settings= @(
"""EventHubConnectionString=@Microsoft.KeyVault(SecretUri=https://$keyVaultName.vault.azure.net/secrets/EventHubConnectionString/)""",  
"""S3Secret=@Microsoft.KeyVault(SecretUri=https://$keyVaultName.vault.azure.net/secrets/S3Secret/)""",
"""S3AccessKey=@Microsoft.KeyVault(SecretUri=https://$keyVaultName.vault.azure.net/secrets/S3AccessKey/)""",
"""S3BucketName=@Microsoft.KeyVault(SecretUri=https://$keyVaultName.vault.azure.net/secrets/S3BucketName/)""",
"""EventHubName=$eventHubName"""
)
az functionapp config appsettings set -n $functionAppName -g $resourceGroupName --settings @settings -o table
az functionapp config appsettings set -n $functionAppNameElastic -g $resourceGroupName --settings @settings -o table

$appsettings = @{}
$appsettings.Add("EventHubConnectionString",$eventHubConnectionString);
$appsettings.Add("EventHubName", $eventHubName);
$appsettingsFile = [IO.Path]::GetFullPath(".\EventProducer\appsettings.json")
if(Test-path $appsettingsFile) {Remove-item $appsettingsFile}

$appsettings | ConvertTo-Json | Out-File $appsettingsFile
dotnet build .\EventProducer\EventProducer.csproj