extension radius
extension customTypes

@description('The Radius Environment ID.')
param environment string

@description('Administrator password for the MySQL database.')
@secure()
param mysqlPassword string

@description('Username for the OCI registry the containerImages recipe pushes to (the GitHub actor for ghcr.io).')
param registryUsername string

@description('Password/token for the OCI registry the containerImages recipe pushes to (a GitHub token with write:packages for ghcr.io).')
@secure()
param registryPassword string

@description('Recipient address for todo notification emails.')
param notifyTo string

resource todoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'todo-list-app'
  properties: {
    environment: environment
  }
}

resource mysqlDb 'Radius.Data/mySqlDatabases@2025-08-01-preview' = {
  name: 'mysql'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'src/persistence/mysql.js#L31'
    database: 'todos'
    version: '8.0'
    username: 'myadmin'
    password: mysqlPassword
  }
}

// Azure Communication Services Email provisions the mail delivery backend and
// its Azure-managed sender domain, so the application needs no SMTP server.
resource emailService 'Radius.Resources/azureEmailServices@2025-08-01-preview' = {
  name: 'email'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'src/notifications.js#L19'
    dataLocation: 'United States'
    senderUsername: 'donotreply'
  }
}

// Registry push credentials for the containerImages recipe. The name MUST be
// exactly 'radius-ghcr-registry-creds' to match the recipe pack's
// containerImagesRegistrySecretName.
resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: todoApp.id
    data: {
      username: {
        value: registryUsername
      }
      password: {
        value: registryPassword
      }
    }
  }
}

resource todoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'todo-list-app-image'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'Dockerfile'
    build: {
      source: 'git::https://github.com/kachawla/todo-list-app-copy.git?ref=8740ed646c84848e905f56291e6f2005ad64ccd0'
      // The Dockerfile has no FROM --platform=$BUILDPLATFORM / TARGETARCH
      // cross-compilation support, so restrict the build to the cluster node arch.
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource todoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'todo-list-app'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'src/index.js#L18'
    containers: {
      todo: {
        image: todoImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          MYSQL_HOST: {
            value: mysqlDb.properties.host
          }
          MYSQL_USER: {
            value: 'myadmin'
          }
          MYSQL_PASSWORD: {
            value: mysqlPassword
          }
          MYSQL_DB: {
            value: 'todos'
          }
          NOTIFY_FROM: {
            value: emailService.properties.senderAddress
          }
          NOTIFY_TO: {
            value: notifyTo
          }
          COMMUNICATION_SERVICES_CONNECTION_STRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: emailService.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
      }
    }
  }
}
