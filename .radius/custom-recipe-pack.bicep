extension radius

// Registers the recipe that provisions Azure Communication Services Email for
// the generated Radius.Resources/azureEmailServices type. Register this pack on
// the target Environment before deploying the application.
resource emailRecipePack 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'todo-list-app-email'
  properties: {
    recipes: {
      'Radius.Resources/azureEmailServices': {
        kind: 'bicep'
        source: 'ghcr.io/kachawla/todo-list-app-copy/azure-email-services-recipe:v1'
      }
    }
  }
}
