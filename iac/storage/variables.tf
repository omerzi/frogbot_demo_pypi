variable "module_enabled" {
  default = true
}

variable "region" {
}

variable "region_name_storage" {
}

variable "account_tier" {
}

variable "account_kind" {
}

variable "allow_blob_public_access" {
default = false
}
variable "allow_nested_items_to_be_public" {
  default = false
}
variable "min_tls_version" {
  default = "TLS1_0"
}
variable "cross_tenant_replication_enabled" {
  default = false
}

variable "deploy_name" {
}

variable "resource_group_name" {
}

variable "k8s_cluster_name" {
}

variable "environment" {
}

variable "account_replication_type" {
  default = "RAGRS"
}
variable "azure_pipelines" {
  default = false
}
variable "enable_advanced_threat_protection" {
  default = "false"
}

variable "enable_https_traffic_only" {
  default = true
}

