variable "module_enabled" {
  default = 0
}

variable "region" {}

variable "deploy_name" {}

variable "resource_group_name" {}

variable "private_subnet" {}

variable "environment" {}

variable "privatelink_map" {}

variable "narcissus_domain_short" {}

variable "cloud_subscription" {}

variable "kubernetes_cluster_id" {
  default = ""
}

variable "kubernetes_cluster_name" {
  default = ""
}

variable "isMainCluster" {
  default = false
}
variable "zones" {
  default = []
}

variable "enable_tags" {
  default = false
}
