extension radius

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

@description('Hostname of the SMTP server the notifier sends email through.')
param smtpHost string

@description('Port of the SMTP server the notifier sends email through.')
param smtpPort string = '587'

@description('Username used to authenticate to the SMTP server.')
param smtpUser string

@description('Password used to authenticate to the SMTP server.')
@secure()
param smtpPassword string

@description('From address used on todo notification emails.')
param notifyFrom string

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
      source: 'git::https://github.com/kachawla/todo-list-app-copy.git?ref=16e7630f7eabcccc06b689361d4e522a4ee843d3'
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

resource notifierImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'notifier-image'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'services/notifier/Dockerfile'
    build: {
      source: 'git::https://github.com/kachawla/todo-list-app-copy.git//services/notifier?ref=16e7630f7eabcccc06b689361d4e522a4ee843d3'
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

resource notifierContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'notifier'
  properties: {
    environment: environment
    application: todoApp.id
    codeReference: 'services/notifier/src/index.js#L67'
    containers: {
      notifier: {
        image: notifierImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3001
          }
        }
        env: {
          PORT: {
            value: '3001'
          }
          SMTP_HOST: {
            value: smtpHost
          }
          SMTP_PORT: {
            value: smtpPort
          }
          SMTP_SECURE: {
            value: 'false'
          }
          SMTP_USER: {
            value: smtpUser
          }
          SMTP_PASSWORD: {
            value: smtpPassword
          }
          NOTIFY_FROM: {
            value: notifyFrom
          }
          NOTIFY_TO: {
            value: notifyTo
          }
        }
      }
    }
  }
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
          NOTIFIER_URL: {
            value: 'http://${notifierContainer.properties.hosts['notifier']}:3001'
          }
        }
      }
    }
  }
}
