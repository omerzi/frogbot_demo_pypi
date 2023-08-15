variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "region_zone" {
}

variable "deploy_name" {
}

variable "service_name" {
}

variable "network" {
}

variable "subnetwork" {
}
variable "sdm_source_ranges_ips" {
}
variable "sdm_port" {
  default = ["5000"]
}
variable "machine_type" {
}

variable "disk_size_gb" {
}

variable "compute_image" {
}

variable "instance_count" {
}

variable "instance_tags" {
  type = list(string)
}

variable "source_tags" {
  type = list(string)
}

variable "target_tags" {
  type = list(string)
}

variable "ssh_source_ranges" {
  type = list(string)
}
variable "sshproxy_ips" {
  default = []
}
variable "protocol" {
}

variable "ports" {
  type = list(string)
}

variable "ssh_key" {
}

variable "environment" {
}

variable "public" {
}

variable service_account_email {
}