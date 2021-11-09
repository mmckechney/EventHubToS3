@description('Function App Name')
param functionAppName string 

@description('Key Vault Name')
param keyVaultName string = '${functionAppName}keyvault'

@description('EventHub Namespace Name')
param eventHubNamespaceName string = '${functionAppName}ehnamespace'

@description('EventHub Name')
param eventHubName string = '${functionAppName}_ehname'

@description('Storage account Name')
param storageAccountName string = '${toLower(functionAppName)}storage'

@description('App Service Plan Name')
param appServicePlanName string = '${functionAppName}_appsvcplan'

@description('Resource Location')
param location string = resourceGroup().location

@description('App Insights Name')
param appInsightsName string= '${functionAppName}_appinsights'

@allowed([
  'Basic'
  'Standard'
])
@description('The messaging tier for service Bus namespace')
param eventhubSku string = 'Standard'

@allowed([
  1
  2
  4
])
@description('MessagingUnits for premium namespace')
param skuCapacity int = 1


resource functionApp_resource 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
    }
  properties: {
    enabled: true
    siteConfig:{
      appSettings:[
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference('microsoft.insights/components/${appInsights_resource.name}', '2015-05-01').InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value:'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys('${storageAccount_resource.id}','2021-06-01').keys[0].value};EndpointSuffix=core.windows.net'  
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys('${storageAccount_resource.id}','2021-06-01').keys[0].value};EndpointSuffix=core.windows.net'  
        }
      ]
    }
    hostNameSslStates: [
      {
        name: '${functionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: appServicerPlan_resource.id
  }
  dependsOn:[
    appInsights_resource
    storageAccount_resource
  ]
}


resource keyVault_resource 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }  
    accessPolicies:[
      {
        tenantId: subscription().tenantId
        objectId:functionApp_resource.identity.principalId
        permissions:  {
          secrets:[
            'set'
            'list'
            'get'
          ]
        }
        
      }
    ]
  }
 
}


resource eventHubNamespace_resource 'Microsoft.EventHub/namespaces@2017-04-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventhubSku
    tier: eventhubSku
    capacity: skuCapacity
  }
}

resource eventHubNamespace_eventHubName_resource 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventHubNamespace_resource.name}/${eventHubName}'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 32
    status: 'Active'
  }
  dependsOn: [
    eventHubNamespace_resource
  ]
}


resource storageAccount_resource 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: 'eastus'
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_0'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource appInsights_resource 'microsoft.insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appServicerPlan_resource 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'functionapp'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
  dependsOn:[
    storageAccount_resource
  ]
}


