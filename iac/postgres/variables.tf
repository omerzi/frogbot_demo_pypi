variable "module_enabled" { default = true }

variable "postgres_dbs" { type = any }

variable "region" {}

variable "dr_region" {}

variable "deploy_name" {}

variable "resource_group_name" {}

variable "dbs_count" {}

variable "create_sdm_resources" {
  default = false
}

variable "user_name" {}

variable "user_password" {}
variable "auto_grow_enabled" {
  default = true
}
variable "private_subnet" {}

variable "data_subnet" {}

variable "fw_rule_sshproxy_IP" {}

variable "private_dns_id" {}

variable "private_dns_name" {}

variable "backup_retention_days" { default = 7 }

variable "environment" {}

variable "narcissus_domain_short" { type = string }

variable "ssl_minimal_tls_version_enforced" {
  default = "TLSEnforcementDisabled"
}


//variable "fw_rule_SDM_agent_IP" { //TODO: Replaced with provate-link
//  type = "list"
//  default = [
//    "3.232.202.49",
//    "13.76.167.39",
//    "35.174.242.222",
//    "18.236.154.167",
//    "52.59.214.169",
//    "18.210.7.251",
//    "3.122.127.200",
//    "18.202.212.105",
//    "13.235.59.200",
//    "13.229.144.157",
//    "13.211.215.34",
//    "54.64.89.27",
//    "13.92.102.101",
//    "40.78.93.78",
//    "137.116.209.68",
//    "52.170.207.128",
//    "52.147.2.72"
//  ]
//}