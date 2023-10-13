param appServiceName string = 'devexperience-devbox'
param vnetName string = 'devexperience-devbox'
param subnetName string = 'devexperience-devbox-subnet'
param location string = 'westeurope'
param virtualNetworkId string = '/subscriptions/878f6558-9f86-430e-a0da-c76c12722d97/resourceGroups/devexperience-devbox/providers/Microsoft.Network/virtualNetworks/devexperience-devbox' // it is expected that this module will be invoked from parent bicep and VNET will be created from there and ID passed as a parameter.
param targetSubResource array = ['sites']

/*
Deployes an App Service Plan and App service with a private endpoint in the existing subnet. The app service is configured to use the private DNS zone.
*/

// Deploy App Service Plan

resource serverfarms_devexperience_devbox_name_resource 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServiceName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  kind: 'app'
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
}

// Deploy Web App

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: serverfarms_devexperience_devbox_name_resource.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'  
  }
}


resource sites_devexperience_devbox_name_web 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: appService
  name: 'web'
  location: location
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
      'hostingstart.html'
    ]
    netFrameworkVersion: 'v7.0'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLoggingEnabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
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
    publicNetworkAccess: 'Disabled'
    localMySqlEnabled: false
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.2'
    ftpsState: 'FtpsOnly'
    preWarmedInstanceCount: 0
    elasticWebAppScaleLimit: 0
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 0
    azureStorageAccounts: {}
  }
}


var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  location: location
  name: appServiceName
  properties: {
    subnet: {
      id: subnetId
    }
    customNetworkInterfaceName: 'devexperience-devbox-nic'
    privateLinkServiceConnections: [
      {
        name: appServiceName
        properties: {
          privateLinkServiceId: appService.id
          groupIds: targetSubResource
        }
      }
    ]
  }
  tags: {}
  dependsOn: []
}

resource privatelink_azurewebsites_net_zone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: {}
  properties: {}
  dependsOn: [
    privateEndpoint
  ]
}

resource privatelink_azurewebsites_net_links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${'privatelink.azurewebsites.net'}/${uniqueString(virtualNetworkId)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
  dependsOn: [
    privatelink_azurewebsites_net_zone
  ]
}


resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: privatelink_azurewebsites_net_zone.id
        }
      }
    ]
  }
}

