output "postgres_fqdn" {
  value = element(concat(azurerm_postgresql_server.postgres.*.fqdn, [""]), 0)
}

output "postgres_server_name" {
  value = element(concat(azurerm_postgresql_server.postgres.*.name, [""]), 0)
}

output "postgres_admin_username" {
  value = element(
    concat(
      azurerm_postgresql_server.postgres.*.administrator_login,
      [""],
    ),
    0,
  )
}

output "postgres_admin_password" {
  value = element(
    concat(
      azurerm_postgresql_server.postgres.*.administrator_login_password,
      [""],
    ),
    0,
  )
}

