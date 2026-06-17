param appName string = 'nodejs-app'
param location string = resourceGroup().location
param acrName string
param userAssignedIdentityName string

// ─── Log Analytics Workspace ───────────────────────────────
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${appName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ─── Azure Container Registry ──────────────────────────────
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// ─── User Assigned Identity (existing) ────────────────────
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, uami.id, 'acrpull')
  scope: acr
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions','7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull)
    principalType: 'ServicePrincipal'
  }
}

// ─── Container Apps Environment ────────────────────────────
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: '${appName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ─── Container App ─────────────────────────────────────────
resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${appName}-container'
  location: location

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }

  properties: {
    managedEnvironmentId: containerAppEnv.id

    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }

      registries: [
        {
          server: acr.properties.loginServer
          identity: uami.id
        }
      ]
    }

    template: {
      containers: [
        {
          name: appName
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'PORT'
              value: '8080'
            }
          ]
        }
      ]

      scale: {
        minReplicas: 1
        maxReplicas: 5
      }
    }
  }
}

output acrLoginServer string = acr.properties.loginServer
output containerAppName string = containerApp.name
