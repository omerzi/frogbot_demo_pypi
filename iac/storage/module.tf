resource "azurerm_storage_account" "account" {
  count                           = var.module_enabled ? 1 : 0
  name                            = var.azure_pipelines ?"${var.deploy_name}${var.environment}pipelines${var.region_name_storage}" : "${var.deploy_name}${var.environment}${var.region_name_storage}"
  resource_group_name             = "MC_${var.resource_group_name}_${var.k8s_cluster_name}_${var.region}"
  location                        = var.region
  account_tier                    = var.account_tier
  account_kind                    = var.account_kind
  account_replication_type        = var.account_replication_type
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  cross_tenant_replication_enabled = var.cross_tenant_replication_enabled
  // enable_advanced_threat_protection = "${var.enable_advanced_threat_protection}"
  enable_https_traffic_only       = var.enable_https_traffic_only
  min_tls_version                  = var.min_tls_version
  lifecycle {
    ignore_changes = [name] // workaround for the initial manuall creation of storage with a different naming convention
  }
}

//resource "azurerm_storage_share" "share" {
//  name = "${var.deploy_name}-${var.environment}-${var.region}"
//
//  resource_group_name  = "${var.resource_group_name}"
//  storage_account_name = "${azurerm_storage_account.account.name}"
//
//}
