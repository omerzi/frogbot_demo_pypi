//data "azurerm_network_security_group" "nsg" {
//  name                = "${var.subnet}-sg"
//  resource_group_name = var.resource_group_name
//}

resource "random_string" "password" {
  count   = var.module_enabled ? 1 : 0
  length  = 16
  special = true
}

data "template_file" "startup-script" {
  template = file("${path.module}/files/${var.service_name}_bootstrap.sh")

  vars = {
    mmsGroupId    = var.mmsGroupId
    mmsApiKey     = var.mmsApiKey
  }
}

# Create public IPs
resource "azurerm_public_ip" "tfnatip_public" {
  count               = !var.legacy && var.module_enabled && var.public_ip ? var.instance_count : 0
  name                = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"

  tags = {
    environment = var.environment
  }
}


# Create network interface with public ip
resource "azurerm_network_interface" "nic" {
  count               = !var.legacy && var.module_enabled ? var.instance_count : 0
  name                = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
  location            = var.region
  resource_group_name = var.resource_group_name
  enable_ip_forwarding = "false"

  ip_configuration {
    name                          = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
    subnet_id                     = var.subnet
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip == true ? element(concat(azurerm_public_ip.tfnatip_public.*.id, [""]), count.index) : null
  }

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_interface_security_group_association" "nic_public" {
  count                     = !var.legacy && var.module_enabled && var.public_ip ? var.instance_count : 0
  network_interface_id      = element(concat(azurerm_network_interface.nic.*.id, [""]), count.index)
  network_security_group_id =  var.security_group_id
}



###################################################
###################################################



# LEGACY SECTION:

# Create network interface with private ip only
resource "azurerm_network_interface" "nic_private" {
  count                     = var.legacy && var.module_enabled && !var.public_ip ? var.instance_count : 0
  name                      = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
  location                  = var.region
  resource_group_name       = var.resource_group_name

  ip_configuration {
    name                          = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
    subnet_id                     = var.subnet
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip == true ? element(concat(azurerm_public_ip.tfnatip_public.*.id, [""]), toint(count.index)) : null
  }

  tags = {
    environment = var.environment
  }
}


# Create virtual machine with data storage
resource "azurerm_virtual_machine" "tfnatvm" {
  count                 = var.legacy && var.module_enabled && var.data_storage ? var.instance_count : 0
  name                  = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
  location              = var.region
  resource_group_name   = var.resource_group_name
  network_interface_ids = var.public_ip == true ? [azurerm_network_interface.nic_public.*.id[count.index]] : [azurerm_network_interface.nic_private.*.id[count.index]]
  vm_size                = var.machine_type

  storage_os_disk {
    name              = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
// storage_data_disk {
//   name              = "${var.deploy_name}-${var.region}-${var.service_name}-data-${count.index}"
//   caching           = "ReadWrite"
//   create_option     = "empty"
//   managed_disk_type = "Premium_LRS"
//   disk_size_gb      = "1023"
//   lun               = 0
// }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
    admin_username = "ubuntu"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = var.ssh_key
    }
  }
  tags = {
    environment = var.environment
  }
}

resource "azurerm_virtual_machine_extension" "natvmext" {
  count = var.legacy && var.module_enabled ? var.instance_count : 0
  name  = "${var.deploy_name}-${var.region}-${var.service_name}"
  virtual_machine_id   = azurerm_virtual_machine.tfnatvm[count.index].id
  #virtual_machine_id   = "/subscriptions/ef3946c9-1832-4403-bc50-27ebe9cd594a/resourceGroups/k8s-stg-eastus/providers/Microsoft.Compute/virtualMachines/k8s-stg-eastus-sshproxy-0"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(data.template_file.startup-script.rendered)}"
    }

SETTINGS


  tags = {
    environment = var.environment
  }
  lifecycle {
    ignore_changes = [ settings ]
  }
}

# Create public IPs
resource "azurerm_public_ip" "tfnatip" {
  count               = var.legacy && var.module_enabled && var.public_ip ? var.instance_count : 0
  name                = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"

  tags = {
    environment = var.environment
  }
}

# Create network interface with public ip
resource "azurerm_network_interface" "nic_public" {
  count                     = var.legacy && var.module_enabled && var.public_ip ? var.instance_count : 0
  name                      = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
  location                  = var.region
  resource_group_name       = var.resource_group_name
  enable_ip_forwarding      = "false"

  ip_configuration {
    name                          = "${var.deploy_name}-${var.region}-${var.service_name}-${count.index}"
    subnet_id                     = var.subnet
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip == true ? element(concat(azurerm_public_ip.tfnatip.*.id, [""]), count.index) : null
  }

  tags ={
    environment = var.environment
  }
}

