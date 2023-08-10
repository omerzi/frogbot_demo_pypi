resource "azurerm_network_security_rule" "natgw-nsg" {
  count                       = var.module_enabled ? 1 : 0
  name                        = "all-traffic-from-subnets"
  priority                    = "100"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.vpc_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = "public-sg"
  depends_on                  = [azurerm_network_security_group.nsg]
}

resource "azurerm_network_security_rule" "sshproxy-nsg" {
  count                       = var.module_enabled ? 1 : 0
  name                        = "ssh-traffic-from-jfrog-office"
  priority                    = "100"
  direction                   = "Inbound"
  access                      = var.sshproxy_nsg_access
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.ssh_source_ranges
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = "mgmt-sg"
  depends_on                  = [azurerm_network_security_group.nsg]
}

resource "azurerm_network_security_rule" "sdm-nsg" {
  count                       = var.module_enabled ? 1 : 0
  name                        = "SDM-traffic-from-jfrog-office"
  priority                    = "101"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5000"
  source_address_prefixes     = concat(var.ssh_source_ranges,var.sdm_source_ranges_ips)
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = "mgmt-sg"
  depends_on                  = [azurerm_network_security_group.nsg]
}

resource "azurerm_network_security_rule" "mongo-nsg" {
  count                       = var.module_enabled ? 1 : 0
  name                        = "mongo-traffic-from-private-subnets"
  priority                    = "100"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "27017"
  source_address_prefixes     = var.mongo_source_ranges
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = "data-sg"
  depends_on                  = [azurerm_network_security_group.nsg]
}

resource "azurerm_network_security_rule" "Block_VnetInBound-nsg" {
  count                       = var.module_enabled ? 1 : 0
  name                        = "Block_VnetInBound"
  priority                    = "102"
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.source_address_prefix
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = "mgmt-sg"
  depends_on                  = [azurerm_network_security_group.nsg]
}

resource "azurerm_network_security_group" "nsg" {
  count               = var.module_enabled ? length(var.subnet_names) : 0
  name                = "${var.subnet_names[count.index]}-sg"
  location            = var.region
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "nsg" {
  count                     = var.module_enabled ? length(var.subnet_names) : 0
  subnet_id                 = var.subnet_ids[count.index]
  network_security_group_id = element(azurerm_network_security_group.nsg.*.id, count.index)
}

# ASG
resource "azurerm_application_security_group" "asg" {
  count               = var.module_enabled ? length(var.app_names) : 0
  name                = var.app_names[count.index]
  location            = var.region
  resource_group_name = var.resource_group_name
}

