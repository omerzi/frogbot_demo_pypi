output "k8s_nat_public_ips" {
  value = azurerm_public_ip.k8s_nat_public_ip.*.ip_address
}

output "k8s_nat_public_ids" {
  value = azurerm_public_ip.k8s_nat_public_ip.*.id
}
