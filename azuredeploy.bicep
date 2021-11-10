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

@description('Elastic Premium Function Name')
param functionAppNameElastic string 
param elasticAppServicePlanName string = '${functionAppNameElastic}_appsvcplan'
param elasticAppInsightsName string= '${functionAppNameElastic}_appinsights'
param elasticStorageAccount string = '${toLower(functionAppNameElastic)}storage'

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
      {
        tenantId: subscription().tenantId
        objectId:elasticFunctionApp_resource.identity.principalId
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
  dependsOn:[
    functionApp_resource
    elasticFunctionApp_resource
  ]
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


resource elasticAppInsights_resource 'microsoft.insights/components@2020-02-02' = {
  name: elasticAppInsightsName
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
resource elasticStorage_resource 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: elasticStorageAccount
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
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

resource elasticAppServicePlan_resource 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: elasticAppServicePlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    size: 'EP1'
    family: 'EP'
    capacity: 1
  }
  kind: 'elastic'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}


resource elasticFunctionApp_resource 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppNameElastic
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
    }
  properties: {
    enabled: true
    siteConfig:{
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 1
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
          value: reference('microsoft.insights/components/${elasticAppInsights_resource.name}', '2015-05-01').InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value:'DefaultEndpointsProtocol=https;AccountName=${elasticStorage_resource.name};AccountKey=${listKeys('${elasticStorage_resource.id}','2021-06-01').keys[0].value};EndpointSuffix=core.windows.net'  
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${elasticStorage_resource.name};AccountKey=${listKeys('${elasticStorage_resource.id}','2021-06-01').keys[0].value};EndpointSuffix=core.windows.net'  
        }
      ]
    }
    hostNameSslStates: [
      {
        name: '${functionAppNameElastic}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppNameElastic}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: elasticAppServicePlan_resource.id
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
  dependsOn:[
    elasticAppInsights_resource
    elasticStorage_resource
  ]
}

resource elasticSiteConfig 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: elasticFunctionApp_resource
  name: 'web'
  properties: {
    numberOfWorkers: 1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
    ]
    netFrameworkVersion: 'v6.0'
    phpVersion: '5.6'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLoggingEnabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    publishingUsername: '$ehdemoelastic'
    scmType: 'None'
    use32BitWorkerProcess: true
    webSocketsEnabled: false
    alwaysOn: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: false
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    vnetRouteAllEnabled: false
    vnetPrivatePortsCount: 0
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.0'
    ftpsState: 'AllAllowed'
    preWarmedInstanceCount: 1
    functionAppScaleLimit: 0
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 1
    azureStorageAccounts: {}
  }
  dependsOn:[
    elasticFunctionApp_resource
  ]
}


