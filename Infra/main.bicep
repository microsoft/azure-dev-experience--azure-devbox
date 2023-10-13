param virtualNetworkName string = 'devexperience-devbox'
param subnetName string = 'devexperience-devbox-subnet'
param addressPrefix string = '10.0.0.0/16'
param subnetAddressPrefix string = '10.0.2.0/24'
param name string = 'devexperience-devbox'
param location string = 'westeurope'

var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}


resource dev_center 'Microsoft.DevCenter/devcenters@2023-04-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}



param connection_name string = 'devexperience-devbox'
param domainJoinType string = 'AzureADJoin'
param domainName string = ''
param domainUsername string = ''

@secure()
param domainPassword string = ''
param organizationUnit string = ''

resource devbox_network_connection 'Microsoft.DevCenter/networkconnections@2023-04-01' = {
  name: connection_name
  location: location
  properties: {
    domainJoinType: domainJoinType
    domainName: domainName
    domainUsername: domainUsername
    domainPassword: domainPassword
    subnetId: subnetRef
    organizationUnit: organizationUnit
  }
  dependsOn: [
    virtualNetwork
  ]  
}


param devboxprojectname string = 'devbox-main'
param description string = ''
param maxDevBoxesPerUser int = 2

var devCenterRef = resourceId('Microsoft.DevCenter/devcenters', name)

resource devbox_project 'Microsoft.DevCenter/projects@2023-04-01' = {
  name: devboxprojectname
  location: location
  properties: {
    description: description
    devCenterId: devCenterRef
    maxDevBoxesPerUser: maxDevBoxesPerUser
  }
  dependsOn: [
    dev_center
  ]    
}


resource devcenters_devexperience_devbox_name_Developer 'Microsoft.DevCenter/devcenters/environmentTypes@2023-04-01' = {
  parent: dev_center
  name: 'Developer'
  properties: {}
}



var imageId = 'microsoftvisualstudio_visualstudioplustools_vs-2022-ent-general-win11-m365-gen2'


resource devcenters_devexperience_devbox_name_vs2022 'Microsoft.DevCenter/devcenters/devboxdefinitions@2023-04-01' = {
  parent: dev_center
  name: 'vs2022'
  location: location
  properties: {
    imageReference: {
      id: '${dev_center.id}/galleries/default/images/${imageId}'
    }
    sku: {
      name: 'general_i_8c32gb256ssd_v2'
    }
    hibernateSupport: 'Disabled'
  }
  dependsOn: [
    dev_center
  ]
}


resource devcenters_devexperience_devbox_name_devcenters_devexperience_devbox_name 'Microsoft.DevCenter/devcenters/attachednetworks@2023-04-01' = {
  parent: dev_center
  name: connection_name
  properties: {
    networkConnectionId: devbox_network_connection.id
  }
  dependsOn: [
    dev_center
    devbox_network_connection
  ]
}


resource projects_devbox_main_name_main 'Microsoft.DevCenter/projects/pools@2023-04-01' = {
  parent: devbox_project
  name: 'main'
  location: location
  properties: {
    devBoxDefinitionName: 'vs2022'
    networkConnectionName: 'devexperience-devbox'
    licenseType: 'Windows_Client'
    localAdministrator: 'Enabled'
  }
  dependsOn: [
    devbox_project
  ]

}


resource devbox_keyvault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: 'da5cf048-6ca0-4635-a576-f7a5a5a84722'
    accessPolicies: []
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    vaultUri: 'https://${name}.vault.azure.net/'
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
  }
}


resource devbox_keyvault_secret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: devbox_keyvault
  name: name
  location: location
  properties: {
    attributes: {
      enabled: true
    }
  }
}


param roleDefinitionId string = '4633458b-17de-408a-b874-0445c86b69e6'


output roleDefinitionOut string = roleDefinitionId

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleDefinitionId, resourceGroup().id)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: dev_center.identity.principalId
    roleDefinitionId: roleDefinitionId
  }
}


// Deploy DevBox Catalog

resource dev_catalog 'Microsoft.DevCenter/devcenters/catalogs@2023-04-01' =  {
  parent: dev_center
  name: name
  properties: {
    adoGit: {
      uri: 'https://dev.azure.com/swisscsurockstars/devexperience-devbox/_git/devexperience-devbox'
      secretIdentifier: 'https://devexperience-devbox.vault.azure.net/secrets/devexperience-devbox/d4f2d0ef193a418bad68f371593b466a'
    }
  }
}


module appServicePrivateEndpoints './modules/appservice-with-privateendpoints.bicep' = {
  name: 'appServicePrivateEndpoints'
  params: {
    appServiceName: name
    vnetName: virtualNetworkName
    subnetName: subnetName
    location: location
  }
}

