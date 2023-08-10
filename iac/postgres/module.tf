//locals {
//  private_ep_ip_dns_record_data_path = "/app/private_ep_ip_dns_record_data"
//}

resource "random_string" "password" {
  count   = var.dbs_count !=0 ? 1 : 0
  length  = 16
  special = true
}

resource "azurerm_postgresql_server" "postgres" {
  count = var.dbs_count
  name   = try(var.postgres_dbs[count.index]["name"], "${var.deploy_name}-${var.region}-${var.postgres_dbs[count.index]["name_postfix"]}")

  //  name                = "${var.deploy_name}-${var.region}-postgres"
  location                     = var.region
  resource_group_name          = var.resource_group_name
  sku_name                     = var.postgres_dbs[count.index]["sku"]
  storage_mb                   = var.postgres_dbs[count.index]["override_disk_size"]
  backup_retention_days        = var.postgres_dbs[count.index]["backup_retention_days"]
  auto_grow_enabled            = try(var.postgres_dbs[count.index]["auto_grow_enabled"],var.auto_grow_enabled)
  geo_redundant_backup_enabled = "false"
  ssl_enforcement_enabled      = "true"
  ssl_minimal_tls_version_enforced = var.ssl_minimal_tls_version_enforced
  administrator_login          = var.user_name
  administrator_login_password = var.user_password == "" ? random_string.password[0].result : var.user_password
  version                      = var.postgres_dbs[count.index]["postgres_version"]
  create_mode                  = "Default"

  public_network_access_enabled = false

  //  provisioner "local-exec" { // TODO: add as resource with provider version 2.7+
  //    command = <<EOT
  //      az postgres server replica create \
  //      --name ${azurerm_postgresql_server.postgres.name}-dr \
  //      --resource-group ${var.resource_group_name} \
  //      --source-server ${azurerm_postgresql_server.postgres.name} \
  //      --location ${var.dr_region}
  //      EOT
  //  }
  //  lifecycle {
  //    ignore_changes = [
  //      administrator_login,
  //      administrator_login_password,
  //    ]
  //  }
  tags = merge(data.null_data_source.postgres_tags[count.index].inputs ,
    {
    Environment = var.environment
    Application = try(var.postgres_dbs[count.index]["tags"]["application"], "common")
  })
}

resource "azurerm_private_endpoint" "private_ep_ip" {
  count               = var.dbs_count
  name                = "${azurerm_postgresql_server.postgres[count.index].name}-endpoint"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = var.data_subnet

  private_service_connection {
    name                           = "${azurerm_postgresql_server.postgres[count.index].name}-privateserviceconnection"
    private_connection_resource_id = azurerm_postgresql_server.postgres[count.index].id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
  depends_on = [azurerm_postgresql_server.postgres]
}

resource "azurerm_management_lock" "postgres_delete_lock" {
  count = var.dbs_count
  name       = "postgres-deletion-lock"
  scope      = azurerm_postgresql_server.postgres[count.index].id
  lock_level = "CanNotDelete"
  notes      = "Postgres accidental deletion protection is locked by terraform!"
  depends_on = [
    azurerm_postgresql_server.postgres
  ]
}

//resource "null_resource" "private_ep_ip_dns_record_get" {
//  count    = var.module_enabled ? 1 : 0
//  triggers = {
//    always_run = timestamp()
//  }
//  provisioner "local-exec" {
//    command = <<EOT
//    az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET -t $ARM_TENANT_ID && \
//    az network private-endpoint show \
//    --name ${azurerm_private_endpoint.private_ep_ip[0].name} \
//    --resource-group ${var.resource_group_name} \
//    --query 'customDnsConfigs[0].ipAddresses[0]' \
//    | tr -d "\"" | tr -d "\n" 1> ${local.private_ep_ip_dns_record_data_path}_${var.postgres_name}
//
//EOT
//
//  }
//  depends_on = [azurerm_private_endpoint.private_ep_ip]
//}

//data "local_file" "private_ep_ip_dns_record_data" {
//  count    = var.module_enabled ? 1 : 0
//  filename = "${local.private_ep_ip_dns_record_data_path}_${var.postgres_name}"
//
//  depends_on = [null_resource.private_ep_ip_dns_record_get]
//}

//data "azurerm_private_endpoint_connection" "private_ep_ip" {
//  count               = var.module_enabled ? 1 : 0
//  name                = "${azurerm_postgresql_server.postgres[0].name}-endpoint"
//  resource_group_name = var.resource_group_name
//  depends_on = [azurerm_private_endpoint.private_ep_ip]
//}
//
//locals {
//  private_ep_private_ip = data.azurerm_private_endpoint_connection.private_ep_ip.private_service_connection.0.private_ip_address
//}

resource "azurerm_private_dns_a_record" "private_ep_ip_dns_record" {
  count               = var.dbs_count
  name                = azurerm_postgresql_server.postgres[count.index].name
  zone_name           = var.private_dns_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_ep_ip[count.index].private_service_connection[0].private_ip_address]

  depends_on = [azurerm_private_endpoint.private_ep_ip]
}

resource "azurerm_postgresql_configuration" "idle_in_transaction_session_timeout" {
  count               = var.dbs_count
  name                = "idle_in_transaction_session_timeout"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres[count.index].name
  value               = "300000"
}

resource "azurerm_postgresql_configuration" "connection_throttling" {
  count               = var.dbs_count
  name                = "connection_throttling"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres[count.index].name
  value               = "OFF"
}

resource "azurerm_postgresql_configuration" "log_min_duration_statement" {
  count               = var.dbs_count
  name                = "log_min_duration_statement"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres[count.index].name
  value               = "1000"
}

data "null_data_source" "postgres_tags" {
  count    = var.dbs_count
  inputs = {
    name          = try("${var.postgres_dbs[count.index]["name"]}","${var.deploy_name}-${var.postgres_dbs[count.index]["name_postfix"]}")
    machine_type  = "${var.postgres_dbs[count.index]["sku"]}"
    db_storage_gb = "${var.postgres_dbs[count.index]["override_disk_size"]}"
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
//
//resource "azurerm_postgresql_firewall_rule" "postgress" {
//  count               = "${var.module_enabled}"
//  name                = "k8s-private"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "${var.natgw_private_ip}"
//  end_ip_address      = "${var.natgw_private_ip}"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "postgres2" {
//  count               = "${var.module_enabled}"
//  name                = "il-office"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "82.81.195.5"
//  end_ip_address      = "82.81.195.5"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//
//resource "azurerm_postgresql_firewall_rule" "ALLOW_VPN" {
//  count               = "${var.module_enabled}"
//  name                = "VPN"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "52.16.203.109"
//  end_ip_address      = "52.16.203.109"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "EU-IT-AWS-NATGW" {
//  count               = "${var.module_enabled}"
//  name                = "EU-IT-AWS-NATGW"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "52.215.237.185"
//  end_ip_address      = "52.215.237.185"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "US-IT-AWS-NATGW" {
//  count               = "${var.module_enabled}"
//  name                = "US-IT-AWS-NATGW"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "52.9.243.19"
//  end_ip_address      = "52.9.243.19"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "sshproxy" {
//  count               = "${var.module_enabled}"
//  name                = "sshproxy"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "${var.fw_rule_sshproxy_IP}"
//  end_ip_address      = "${var.fw_rule_sshproxy_IP}"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "sdm_agent_list" { //TODO:Replaced with private-link
//  count               = "${var.module_enabled ? length(var.fw_rule_SDM_agent_IP) : 0}"
//  name                = "sdm_agent_${count.index}"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${var.postgres_name}"
//  start_ip_address    = "${var.fw_rule_SDM_agent_IP[count.index]}"
//  end_ip_address      = "${var.fw_rule_SDM_agent_IP[count.index]}"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "US-Office" {
//  count               = "${var.module_enabled}"
//  name                = "US-Office"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "12.252.18.78"
//  end_ip_address      = "12.252.18.78"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "GlobalVpn1" {
//  count               = "${var.module_enabled}"
//  name                = "GlobalVpn1"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "52.16.203.109"
//  end_ip_address      = "52.16.203.109"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_firewall_rule" "GlobalVpn2" {
//  count               = "${var.module_enabled}"
//  name                = "GlobalVpn2"
//  resource_group_name = "${var.resource_group_name}"
//  server_name         = "${azurerm_postgresql_server.postgres.name}"
//  start_ip_address    = "52.8.67.255"
//  end_ip_address      = "52.8.67.255"
//  depends_on          = ["azurerm_postgresql_server.postgres"]
//}
//
//resource "azurerm_postgresql_virtual_network_rule" "ALLOW-K8S-NODES-ACCESS-PG" {
//  count                                = "${var.module_enabled}"
//  name                                 = "K8S-VNET-ACCESS"
//  resource_group_name                  = "${var.resource_group_name}"
//  server_name                          = "${azurerm_postgresql_server.postgres.name}"
//  subnet_id                            = "${var.private_subnet}"
//  ignore_missing_vnet_service_endpoint = true
//}

resource "sdm_resource" "postgres_sdm" {
  count = var.create_sdm_resources ? var.dbs_count : 0 
    postgres {
        name = "Azure-${lookup(var.postgres_dbs[count.index], "sdm_name",try(var.postgres_dbs[count.index].name,var.postgres_dbs[count.index].name_postfix))}"
        hostname = lookup(var.postgres_dbs[count.index],"sdm_hostname", azurerm_postgresql_server.postgres[count.index].fqdn)
        database = "postgres"
        username = lookup(var.postgres_dbs[count.index],"sdm_username","${azurerm_postgresql_server.postgres[count.index].administrator_login}@${azurerm_postgresql_server.postgres[count.index].name}")
        password = random_string.password[0].result
        port = 5432
        tags = merge(lookup(var.postgres_dbs[count.index], "sdm_tags", null), {region=var.region}, {env = var.environment})
    }
}