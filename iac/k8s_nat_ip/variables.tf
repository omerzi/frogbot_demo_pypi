variable "deploy_name" {
}

variable "sku" {
  default = "standard"
}

variable "ip_version" {
  default = "IPv4"
}

variable "module_enabled" {
  default = 0
}

variable "region" {
}

variable "resource_group_name" {
}

variable "environment" {
}

variable "k8s_nat_public_ips_names" {
  default = []
}
variable "zones" {
  default = []
  
}