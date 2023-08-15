variable "module_enabled" {
  default = true
}

variable "project_name" {
}

variable "region" {
}

variable "region_zone" {
}

variable "deploy_name" {
}

variable "disk_size_gb" {
}

variable "environment" {
  type = string
}

variable "narcissus_domain_short" {
  type = string
}

variable "narcissus_domain_name" {
  type = string
}

variable "filestore_tags" { 
}

variable "vpc_self_link" {
}