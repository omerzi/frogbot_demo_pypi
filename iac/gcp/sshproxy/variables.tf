variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "deploy_name" {
}

variable "network" {
}

variable "subnetwork" {
}

variable "ssh_key" {
}

variable "environment" {
}

variable "sshproxy_map" {
  default = {}
}

variable "ssh_proxy_sa" {}
variable "image_project" {
  default = "ubuntu-os-cloud"
}