data "azurerm_client_config" "main" {
}

data "azurerm_subscription" "main" {
}

resource "random_string" "password" {
  count   = var.module_enabled ? 1 : 0
  length  = 32
  special = true
}

resource "azuread_application" "spn_app" {
  count         = var.module_enabled ? 1 : 0
  display_name  = "${var.name}-${var.region}"
}

resource "azuread_service_principal" "spn" {
  count          = var.module_enabled ? 1 : 0
  application_id = azuread_application.spn_app[0].application_id
}

resource "azuread_service_principal_password" "spn_password" {
  count                = var.module_enabled ? 1 : 0
  service_principal_id = azuread_service_principal.spn[0].id
  value                = random_string.password[0].result
  end_date             = "2299-12-30T23:00:00Z"
}

resource "azurerm_role_assignment" "spn_role" {
  count                = var.module_enabled ? 1 : 0
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.spn[0].id
}

resource "azurerm_role_assignment" "spn_role_pipelines" {
  count                = var.pipelines_module_enabled ? 1 : 0
  scope                = "/subscriptions/${var.pipelines_subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.spn[0].id
}

