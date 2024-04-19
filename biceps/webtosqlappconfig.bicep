param webAppName string
param webAppInVNetName string
param sqlServerNameNoVNet string
param sqlDatabaseName string
param sqlServerInVNetName string
param sqlServerLogin string
param appConfigName string

@secure()
param sqlServerPassword string

var sqlserverConnName = uniqueString(resourceGroup().id, sqlServerNameNoVNet)
var sqlserverVNetConnName = uniqueString(resourceGroup().id, sqlServerInVNetName)
var appConfigConnName = uniqueString(resourceGroup().id, appConfigName)

// get webapp
resource webApp 'Microsoft.Web/sites@2020-06-01' existing = {
  name: webAppName
  scope: resourceGroup()
}

resource webAppInVNet 'Microsoft.Web/sites@2020-06-01' existing = {
  name: webAppInVNetName
  scope: resourceGroup()
}

// get sql server
resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' existing = {
  name: sqlServerNameNoVNet
  scope: resourceGroup()
}

// get sql database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing = {
  name: sqlDatabaseName
  parent: sqlServer
}

resource sqlServerVNet 'Microsoft.Sql/servers@2019-06-01-preview' existing = {
  name: sqlServerInVNetName
  scope: resourceGroup()
}

resource sqlDatabaseVNet 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing = {
  name: sqlDatabaseName
  parent: sqlServerVNet
}

//  get app config
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2022-05-01' existing = {
  name: appConfigName
  scope: resourceGroup()
}

// Create linker between WebApp the SQL server, using secret authentication,  and no VNet.
resource connectionWebAppToSQLNoVNet 'Microsoft.ServiceLinker/linkers@2022-11-01-preview' = {
  name: sqlserverConnName
  scope: webApp
  properties: {
    targetService: {
      id: sqlDatabase.id
      type: 'AzureResource'
    }
    authInfo: {
      authType: 'secret'
      name: sqlServerLogin
      secretInfo: {
        secretType: 'rawValue'
        value: sqlServerPassword
      }
    }
    clientType: 'none'
  }
}

// Create linker between WebApp the SQL server in VNet, using secret authentication,  and private endpoint.
resource connectionWebAppToSQLVNet 'Microsoft.ServiceLinker/linkers@2022-11-01-preview' = {
  name: sqlserverVNetConnName
  scope: webAppInVNet
  properties: {
    targetService: {
      id: sqlDatabaseVNet.id
      type: 'AzureResource'
    }
    authInfo: {
      authType: 'secret'
      name: sqlServerLogin
      secretInfo: {
        secretType: 'rawValue'
        value: sqlServerPassword
      }
    }
    vNetSolution: {
      type: 'privateLink'
    }
    clientType: 'none'
  }
}


// create linker between WebApp and App Config, with managed identity authentication.
resource connectionWebAppToAppConfig 'Microsoft.ServiceLinker/linkers@2022-11-01-preview' = {
  name: appConfigConnName
  scope: webApp
  properties: {
    targetService: {
      id: appConfig.id
      type: 'AzureResource'
    }
    authInfo: {
      authType: 'systemAssignedIdentity'
    }
    clientType: 'none'
  }
}
