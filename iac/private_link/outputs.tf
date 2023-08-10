output "pl_nlb_id" {
  value = var.module_enabled == 0 ? "" : try(azurerm_lb.pl_nlb[0].name, "")
}

output "pl_service_name" {
  value = var.module_enabled == 0 ? "" : try(azurerm_private_link_service.pl_service[0].alias, "")
}

output "pl_service_id" {
  value = var.module_enabled == 0 ? "" : try(azurerm_private_link_service.pl_service[0].id, "")
}

output "pl_nlb_subnets" {
  value = var.module_enabled == 0 ? "" : try(azurerm_lb.pl_nlb[0].frontend_ip_configuration[0].subnet_id, "")
}
