variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "resource_group_name" {
}

variable "vnet_name" {
}
variable "sdm_source_ranges_ips" {
  default = []
}
variable "vpc_cidr" {
}

variable "ssh_source_ranges" {
  type = list(string)
}

variable "source_address_prefix" {
  type = list(string)
}

variable "mongo_source_ranges" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "subnet_names" {
  type = list(string)
}

variable "deploy_name" {
}

variable "app_names" {
  type    = list(string)
  default = ["sshproxy", "mongo", "k8s"]
}

variable "sshproxy_nsg_access" {
  default = ""
}

