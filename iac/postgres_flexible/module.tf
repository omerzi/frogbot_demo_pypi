//locals {
//  private_ep_ip_dns_record_data_path = "/app/private_ep_ip_dns_record_data"
//}

resource "random_string" "password" {
  count   = var.dbs_count !=0 ? 1 : 0
  length  = 16
  special = true
}

resource "azurerm_postgresql_flexible_server" "postgres_flexible" {
  count = var.dbs_count
  name   = try(var.postgres_dbs[count.index]["name"], "${var.deploy_name}-${var.region}-${var.postgres_dbs[count.index]["name_postfix"]}")
  location                     = var.region
  resource_group_name          = var.resource_group_name
  sku_name                     = lookup(var.postgres_dbs[count.index],"sku","MO_Standard_E16ds_v4")
  storage_mb                   = lookup(var.postgres_dbs[count.index],"override_disk_size","1048576")
  backup_retention_days        = lookup(var.postgres_dbs[count.index],"backup_retention_days","35")
  administrator_login          = var.administrator_login
  administrator_password       = var.administrator_password == "" ? random_string.password[0].result : var.administrator_password
  version                      = lookup(var.postgres_dbs[count.index],"postgres_version","13")
  delegated_subnet_id          = var.delegated_subnet_id
  private_dns_zone_id          = var.private_dns_zone_id
  maintenance_window {
   day_of_week =  var.maintenance_window.day_of_week
   start_hour =  var.maintenance_window.start_hour
   start_minute =  var.maintenance_window.start_minute
  }

 tags = merge(data.null_data_source.postgres_flexible[count.index].inputs ,
    {
    Environment = var.environment
    Application = try(var.postgres_dbs[count.index]["tags"]["application"], "common")
  })
  ###for now there is no need###
  # high_availability  {
  #   mode = var.mode
  # }

 lifecycle {
   ignore_changes =[
  zone
   ]
 }

}


data "null_data_source" "postgres_flexible" {
  count    = var.dbs_count
  inputs = {
    name          = try("${var.postgres_dbs[count.index]["name"]}","${var.deploy_name}-${var.postgres_dbs[count.index]["name_postfix"]}")
    machine_type  = lookup("${var.postgres_dbs[count.index]}","sku","Standard_E16ds_v4")
    db_storage_gb = lookup("${var.postgres_dbs[count.index]}","override_disk_size",1048576)
    environment   = var.environment
    jfrog_region  = var.narcissus_domain_short
    cloud_region  = var.region
    owner         = contains(keys(var.postgres_dbs[count.index].tags), "owner") ? var.postgres_dbs[count.index].tags["owner"] : "DevOps"
    customer      = contains(keys(var.postgres_dbs[count.index].tags), "customer") ? var.postgres_dbs[count.index].tags["customer"] : "shared"
    purpose       = contains(keys(var.postgres_dbs[count.index].tags), "purpose") ? var.postgres_dbs[count.index].tags["purpose"] : "all-JFrog-apps"
    workload_type = contains(keys(var.postgres_dbs[count.index].tags), "workload_type") ? var.postgres_dbs[count.index].tags["workload_type"] : "main"
    application   = contains(keys(var.postgres_dbs[count.index].tags), "application") ? var.postgres_dbs[count.index].tags["application"] : "all"
  }
}
resource "azurerm_management_lock" "flexible_lock" {
  count    = var.dbs_count
  name       = "flexiable-protect"
  scope      = azurerm_postgresql_flexible_server.postgres_flexible[count.index].id 
  lock_level = "CanNotDelete"
}



