variable "deploy_name" {
  
}
variable "region" {
  
}
variable "pl_node_pool" {
  
}
variable "project_name" {
  
}
variable "module_enabled" {
  
}
variable "network" {
  
}
variable "ports" {
  default = ["80","443"]
}
variable "log_config" {
  default = true
}
variable "pl_hc" {
  default = {
  check_interval_sec = 3
  healthy_threshold  = 2
  unhealthy_threshold = 1
  timeout_sec        = 1
  }
}
variable "lb_subnet" {
  
}
variable "pl_node_pool_npx02" {
  default = ""
}
variable "pl_node_pool_npx" {
  default = ""
}
variable "pl_subnet" {
  
}