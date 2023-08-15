variable "module_enabled" {
  default = true
}

variable "project_name" {
}

variable "region" {
}

variable "vpc_map" {
  default = {}
}

variable "deploy_name" {
}

variable "is_sub_region" {
  default = false
}

variable "vpc_self_link" {
  default = ""
}
variable "private_vpc_connection" {
  default = false
}

variable "enable_endpoint_independent_mapping" {
  default = false
}
variable "bgp_keepalive_interval" {
  default = 0
}
variable "private_ip_address" {
  
}