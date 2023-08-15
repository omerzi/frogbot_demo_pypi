variable "module_enabled" {
  default = true
}

variable "project_name" {
}

variable "region" {
}

variable "deploy_name" {
}

variable "user_name" {
}
variable "insights_config" {
  default = []
}
variable "user_password" {
}

variable "backup_configuration" {
  type = list(any)
}
variable "central_backup_location" {
default = null
}
variable "maintenance_window" {
  type = list(any)
}

variable "natgw_ip" {
  default = ""
}

variable "private_network" {
}

variable "authorized_networks_list" {
  type = list(string)
  default = []
}

variable "dbs_count" {
}

variable "create_sdm_resources" {
  default = false
}

variable "postgres_dbs" {
}

variable "availability_type" {
}

variable "purpose" {
  type = string
  default = "all-JFrog-apps"
}

variable "customer" {
  type = string
  default = "shared"
}

variable "workload_type" {
  type = string
  default = "main"
}

variable "narcissus_domain_short"{
  type = string
}

variable "narcissus_domain_name"{
  type = string
}
variable "environment" {
  type = string
}

variable "require_ssl" {}