variable "module_enabled" { default = true }

variable "postgres_dbs" { type = any }

variable "region" {}

variable "deploy_name" {}

variable "resource_group_name" {}

variable "dbs_count" {}

variable "administrator_login" {}

variable "private_dns_zone_id" {}

variable "backup_retention_days" { default = 7 }

variable "environment" {}

variable "narcissus_domain_short" { type = string }

variable "administrator_password" {
  default = "" 
}
variable "create_mode"{
    default = "Default"
}
variable "mode" {
  default = "ZoneRedundant"
}
variable "private_dns_name" {
}
variable "delegated_subnet_id" {
}
variable "maintenance_window" {
  default = {
    day_of_week = 0
    start_hour = 8
    start_minute = 0 
  }
}