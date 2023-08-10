
output "postgres_flexible_id" {
  value =  var.dbs_count > 0 ? azurerm_postgresql_flexible_server.postgres_flexible[0].id : ""
}
output "postgres_flexible_fqdn" {
  value = var.dbs_count > 0  ? azurerm_postgresql_flexible_server.postgres_flexible[0].fqdn : ""
}