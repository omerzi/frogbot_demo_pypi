variable "module_enabled" {
  default = true
}
variable "rbac_admin_roles"{
  
}

variable "rbac_readonly_roles"{
  
}
variable "region" {
}

variable "deploy_name" {
}

variable "resource_group_name" {
}

variable "cluster_version" {
}

variable "cluster_name" {

}

variable "node_count" {
}

variable "node_size" {
}

variable "node_disk_size_gb" {
}

variable "environment" {
}

variable "ssh_key" {
}

variable "subnet" {
}

variable "tenant_id" {
}

variable "lb_sku" {
}

variable "pod_cidr" {
}

variable "pipelines_nodes" {
  default = 0
}

variable "api_server_authorized_ip_ranges" {
  type = list
}

variable "enable_auto_scaling" {
  default = true
}

variable "aks_pp_map"{

}

variable "nat_public_ip_lb_sku" {}