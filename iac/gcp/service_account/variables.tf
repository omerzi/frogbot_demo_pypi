variable "module_enabled" {
  default = true
}

variable "deploy_name" {
}

variable "region" {
}

variable "roles" {
  type = list(string)
}

variable "gcp_project" {

}
