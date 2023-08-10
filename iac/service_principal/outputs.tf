output "sp_password" {
  value = element(
    concat(
      azuread_service_principal_password.spn_password.*.value,
      [""],
    ),
    0,
  )
  sensitive = true
}

output "sp_client_id" {
  value = element(
    concat(azuread_service_principal.spn.*.application_id, [""]),
    0,
  )
}

output "tenant_id" {
  value = data.azurerm_client_config.main.tenant_id
}

