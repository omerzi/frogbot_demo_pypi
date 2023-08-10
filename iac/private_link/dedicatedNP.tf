resource "azurerm_kubernetes_cluster_node_pool" "nginxplus" {
  count                 = can(var.privatelink_map.dedicated_nodepool) ? 1 : 0
  name                  = lookup(var.privatelink_map.dedicated_nodepool, "name")
  kubernetes_cluster_id = var.kubernetes_cluster_id
  vm_size               = lookup(var.privatelink_map.dedicated_nodepool, "instance_type")
  enable_auto_scaling   = lookup(var.privatelink_map.dedicated_nodepool, "enable_auto_scaling", false)
  min_count             = lookup(var.privatelink_map.dedicated_nodepool, "min_size", 1)
  max_count             = lookup(var.privatelink_map.dedicated_nodepool, "max_size", 100)
  os_disk_size_gb       = lookup(var.privatelink_map.dedicated_nodepool, "disk_size", 500)
  node_taints           = ["privatelink=true:NoSchedule"]
  workload_runtime      = lookup(var.privatelink_map.dedicated_nodepool, "workload_runtime", null)
  node_labels = var.enable_tags ? local.privatelink_labels : {}
  vnet_subnet_id        = var.private_subnet
  tags = merge({
    cluster-autoscaler-enabled = lookup(var.privatelink_map.dedicated_nodepool, "enable_auto_scaling", false) ? "false" : "true"
    cluster-autoscaler-name    = lookup(var.privatelink_map.dedicated_nodepool, "cluster_dns_prefix" ,var.kubernetes_cluster_name)
    min                        = 3
    max                        = 100
  }, var.enable_tags ? local.privatelink_tags : {})
}
