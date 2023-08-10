locals {
  privatelink = {
    enable_pl = var.isMainCluster && var.module_enabled != 0 ? 1 : 0
    lb        = {
      http = {
        protocol     = try(var.privatelink_map.load_balancer.protocol.http, "Tcp")
        listen_port  = try(var.privatelink_map.load_balancer.listener_port.http, 80)
        backend_port = try(var.privatelink_map.load_balancer.backend_port.http, 80)
      }
      https = {
        protocol     = try(var.privatelink_map.load_balancer.protocol.https, "Tcp")
        listen_port  = try(var.privatelink_map.load_balancer.listener_port.https, 443)
        backend_port = try(var.privatelink_map.load_balancer.backend_port.https, 443)
      }
    }
  }
}

resource "azurerm_lb" "pl_nlb" {
  
  count               = local.privatelink.enable_pl
  name                = "${var.deploy_name}-${var.region}-pe-nlb"
  location            = var.region
  sku                 = "Standard"
  #  sku_tier                      = "Regional"
  #  availability_zone             = "Zone-Redundant"
  resource_group_name = var.resource_group_name
  

  frontend_ip_configuration {
    name                          = "${var.deploy_name}-${var.region}-pe-fe-ip"
    subnet_id                     = var.private_subnet
    private_ip_address_allocation = "Dynamic"
    zones = var.zones
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_lb_backend_address_pool" "pl_nlb_backend_pool" {
  count           = local.privatelink.enable_pl
  loadbalancer_id = azurerm_lb.pl_nlb[0].id
  name            = "${azurerm_lb.pl_nlb[0].name}-bep"
}

resource "azurerm_lb_probe" "pl_nlb_http_probe" {
  count               = local.privatelink.enable_pl
 // resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.pl_nlb[0].id
  name                = "PE_HC_${local.privatelink.lb.http.backend_port}"
  port                = local.privatelink.lb.http.backend_port
}

resource "azurerm_lb_rule" "pl_nlb_http_rule" {
  count                          = local.privatelink.enable_pl
  name                           = "${azurerm_lb.pl_nlb[0].name}-http"
  //resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.pl_nlb[0].id
  protocol                       = local.privatelink.lb.http.protocol
  frontend_port                  = local.privatelink.lb.http.listen_port
  backend_port                   = local.privatelink.lb.http.backend_port
  enable_floating_ip             = try(var.privatelink_map.load_balancer.enable_floating_ip.http, false)
  enable_tcp_reset               = try(var.privatelink_map.load_balancer.enable_tcp_reset.http, false)
  probe_id                       = azurerm_lb_probe.pl_nlb_http_probe[0].id
  frontend_ip_configuration_name = azurerm_lb.pl_nlb[0].frontend_ip_configuration[0].name
  backend_address_pool_ids      = [azurerm_lb_backend_address_pool.pl_nlb_backend_pool[0].id]
}

resource "azurerm_lb_probe" "pl_nlb_https_probe" {
  count               = local.privatelink.enable_pl
 // resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.pl_nlb[0].id
  name                = "PE_HC_${local.privatelink.lb.https.backend_port}"
  port                = local.privatelink.lb.https.backend_port
}

resource "azurerm_lb_rule" "pl_nlb_https_rule" {
  count                          = local.privatelink.enable_pl
  name                           = "${azurerm_lb.pl_nlb[0].name}-https"
  //resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.pl_nlb[0].id
  protocol                       = local.privatelink.lb.https.protocol
  frontend_port                  = local.privatelink.lb.https.listen_port
  backend_port                   = local.privatelink.lb.https.backend_port
  enable_floating_ip             = try(var.privatelink_map.load_balancer.enable_floating_ip.https, false)
  enable_tcp_reset               = try(var.privatelink_map.load_balancer.enable_tcp_reset.https, false)
  probe_id                       = azurerm_lb_probe.pl_nlb_https_probe[0].id
  frontend_ip_configuration_name = azurerm_lb.pl_nlb[0].frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pl_nlb_backend_pool[0].id]
}

resource "azurerm_private_link_service" "pl_service" {
  count                 = local.privatelink.enable_pl
  name                  = lookup(var.privatelink_map, "pl_name", "${var.deploy_name}-${var.region}-pes")
  resource_group_name   = var.resource_group_name
  location              = var.region
  enable_proxy_protocol = try(var.privatelink_map.pl_service.proxy_protocol_v2, false)

  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.pl_nlb[0].frontend_ip_configuration[0].id]
  #  visibility_subscription_ids                 = ["00000000-0000-0000-0000-000000000000"]

  nat_ip_configuration {
    name                       = "primary"
    subnet_id                  = azurerm_lb.pl_nlb[0].frontend_ip_configuration[0].subnet_id
    private_ip_address_version = "IPv4"
    primary                    = true
  }
  lifecycle {
    ignore_changes = [
      visibility_subscription_ids # TODO: Remove once null_resource.pl_service_visibility can be revoked
    ]
  }
}

data "azurerm_private_link_service" "pl_service_data" {
  count               = local.privatelink.enable_pl
  name                = azurerm_private_link_service.pl_service[0].name
  resource_group_name = azurerm_private_link_service.pl_service[0].resource_group_name
}


resource "null_resource" "pl_service_visibility" {
  # TODO: Revert to resource once provider support * in the visility (Tested on azurerm = 3.0.2)
  count    = local.privatelink.enable_pl
  triggers = {
    check_condition = try(data.azurerm_private_link_service.pl_service_data[0].visibility_subscription_ids[0], "") != "*" ? "statech" : "stateok"
  }
  provisioner "local-exec" {
    #    when       = create
    command    = <<EOT
      az network private-link-service update \
      --name ${azurerm_private_link_service.pl_service[0].name} \
      --resource-group ${var.resource_group_name} \
      --visibility "*" || exit 1
    EOT
    on_failure = fail
  }
  depends_on = [
    azurerm_private_link_service.pl_service
  ]
}

data "null_data_source" "check_nlb_lock_condition" {
  inputs = {
    isLocked = local.privatelink.enable_pl != 0 && try(
      var.privatelink_map.load_balancer.deletion_protection, false
    ) ? 1 : 0
    isReadOnly = local.privatelink.enable_pl != 0 && try(
      var.privatelink_map.load_balancer.readonly_protection, false
    ) ? 1 : 0
  }
  depends_on = [
    azurerm_lb.pl_nlb
  ]
}

resource "azurerm_management_lock" "nlb_read_only_lock" {
  count      = data.null_data_source.check_nlb_lock_condition.inputs.isReadOnly
  name       = "nlb_read_only_lock"
  scope      = azurerm_lb.pl_nlb[0].id
  lock_level = "ReadOnly"
  notes      = "Private Link Load Balancer Modification is protected and locked by terraform!"
  depends_on = [
    data.null_data_source.check_nlb_lock_condition,
    azurerm_lb_backend_address_pool.pl_nlb_backend_pool,
    azurerm_lb_rule.pl_nlb_http_rule,
    azurerm_lb_rule.pl_nlb_https_rule
  ]
}

resource "azurerm_management_lock" "nlb_delete_lock" {
  count      = data.null_data_source.check_nlb_lock_condition.inputs.isLocked
  name       = "nlb_delete_lock"
  scope      = azurerm_lb.pl_nlb[0].id
  lock_level = "CanNotDelete"
  notes      = "Private Link Load Balancer Deletion is protected and locked by terraform!"
  depends_on = [
    data.null_data_source.check_nlb_lock_condition
  ]
}

data "null_data_source" "check_pl_lock_condition" {
  inputs = {
    isLocked = local.privatelink.enable_pl != 0 && try(
      var.privatelink_map.pl_service.deletion_protection, false
    ) ? 1 : 0
    isReadOnly = local.privatelink.enable_pl != 0 && try(
      var.privatelink_map.pl_service.readonly_protection, false
    ) && try(null_resource.pl_service_visibility[0].triggers.check_condition, "") == "stateok" ? 1 : 0
  }
  depends_on = [
    null_resource.pl_service_visibility
  ]
}

#resource "azurerm_management_lock" "pl_service_read_only_lock" {
#  count      = can(null_resource.pl_service_visibility[0].triggers.check_condition) ? data.null_data_source.check_pl_lock_condition.inputs.isReadOnly : 0
#  name       = "pl_service_read_only_lock"
#  scope      = azurerm_private_link_service.pl_service[0].id
#  lock_level = "ReadOnly"
#  notes      = "Private Link Modification is protected and locked by terraform!"
#  depends_on = [
#    data.null_data_source.check_pl_lock_condition
#  ]
#}

resource "azurerm_management_lock" "pl_service_delete_lock" {
  count      = data.null_data_source.check_pl_lock_condition.inputs.isLocked
  name       = "pl_service_delete_lock"
  scope      = azurerm_private_link_service.pl_service[0].id
  lock_level = "CanNotDelete"
  notes      = "Private Link Deletion is protected and locked by terraform!"
  depends_on = [
    data.null_data_source.check_pl_lock_condition
  ]
}
