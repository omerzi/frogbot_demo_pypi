variable "module_enabled" {
  default = true
}

variable "project_name" {
}

variable "region" {
}

variable "deploy_name" {
}

variable "disk_size_gb" {
}

variable "machine_type" {
}

variable "user_name" {
}

variable "user_password" {
}

variable "database_version" {
}

variable "service_name" {
}

variable "backup_configuration" {
  type = list(any)
}

variable "maintenance_window" {
  type = list(any)
}

variable "natgw_ip" {
  type = list(string)
}

