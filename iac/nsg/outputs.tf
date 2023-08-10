### security groups ids ###
output "public_sg" {
  value = element(concat(azurerm_network_security_group.nsg.*.id, [""]), 0)
}

//output "private_sg" {
//  value = element(concat(azurerm_network_security_group.nsg.*.id, [""]), 1)
//}

output "data_sg" {
  value = element(concat(azurerm_network_security_group.nsg.*.id, [""]), 1)
}

output "mgmt_sg" {
  value = element(concat(azurerm_network_security_group.nsg.*.id, [""]), 2)
}

