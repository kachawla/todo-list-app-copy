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
    codeReference: 'src/persistence/mysql.js#L16'
    database: 'todos'
    version: '8.0'
    username: 'myadmin'
    password: mysqlPassword
  }
}

// Registry push credentials for the containerImages recipe. The name must be
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
      source: 'git::https://github.com/kachawla/todo-list-app-copy.git?ref=1705412db2af5d24c304c3d01b9c65c0652f1635'
      // The Dockerfile has no FROM --platform=$BUILDPLATFORM / TARGETARCH
      // cross-compilation support and builds native modules (sqlite3), so
      // restrict the build to the single target platform.
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
    codeReference: 'src/index.js#L17'
    containers: {
      todo: {
        image: todoImage.properties.imageReference
        ports: {
          web: {
            port: 3000
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
        }
      }
    }
    connections: {
      mysqldb: {
        source: mysqlDb.id
      }
    }
  }
}
