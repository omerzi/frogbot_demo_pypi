output "public_ip" {
  value = element(concat(azurerm_public_ip.tfnatip.*.ip_address, [""]), 0)
}

output "private_ip" {
  value = element(
    concat(
      azurerm_network_interface.nic.*.private_ip_address,
      [""],
    ),
    0,
  )
}

output "instance_admin_password" {
  value = random_string.password.*.result
}

