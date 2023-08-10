resource "azurerm_public_ip" "k8s_nat_public_ip" {
  count                   = var.module_enabled
  name                    = var.k8s_nat_public_ips_names == [] ? "${var.resource_group_name}-pub-ip-${count.index}" : var.k8s_nat_public_ips_names[count.index]
  resource_group_name     = var.resource_group_name
  location                = var.region
  allocation_method       = "Static"
  sku                     = var.sku
  ip_version              = var.ip_version
  zones                   = var.zones
//  idle_timeout_in_minutes = var.idle_timeout_in_minutes

  tags = {
    environment = var.environment
    region      = var.region
    purpose     = "Public_Static_NAT_IP"
    created_by  = "Terraform"
    type        = "VNet_Subnet_Outbound"
    deploy_name = var.deploy_name
  }

//  lifecycle {
//    ignore_changes = [
//      tags
//    ]
//  }
}