
data "azurerm_client_config" "current" {
}

data "azuread_group" "devops_infra_group" {
  display_name     = "DevOpsInfraAdmin"
  security_enabled = true
}

# Locals block
locals {

  short_region = {
    "southeastasia"="sea"
    "westeurope"="euw"
    "eastus"="use"
    "westus"="usw"
    "australiaeast"="aue"
  }
  region="${lookup(local.short_region,var.region)}"
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "kv-${var.deploy_name}-byok-${local.region}"
  location                    = var.region
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey"
    ]
  }
  tags = {
    Environment = var.environment
  }
  lifecycle {
    ignore_changes = [
      access_policy
    ]
  }
  depends_on = [
    data.azuread_group.devops_infra_group,
    data.azurerm_client_config.current
  ]
}

resource "azurerm_key_vault_access_policy" "devops_infra_admins_key_access_policy" {
  key_vault_id     = azurerm_key_vault.keyvault.id
  tenant_id        = data.azurerm_client_config.current.tenant_id
  object_id        = data.azuread_group.devops_infra_group.id

  key_permissions = [
    "Backup",
    "Create",
    "Decrypt",
    "Delete",
    "Encrypt",
    "Get",
    "Import",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Sign",
    "UnwrapKey",
    "Update",
    "Verify",
    "WrapKey"
  ]
  depends_on = [
    azurerm_key_vault.keyvault
  ]
}