variable "module_enabled" {
  default = true
}
variable "rbac_admin_roles"{
default = []
}

variable "rbac_readonly_roles"{
default = []
}
variable "project_name" {
}

variable "region" {
}

variable "region_zone" {
}

variable "deploy_name" {
}

variable "network" {
}

variable "subnetwork" {
}

variable "instance_tags" {
  type = list(string)
}

variable "subnet_cidr" {
  type = map(string)
}
variable "oauth_scopes" {
  default = [
     "https://www.googleapis.com/auth/logging.write",
     "https://www.googleapis.com/auth/monitoring",
    ]
}
variable "override_oauth_scope" {
  default = [] 
}
variable "autoscaling_parameters" {
}

variable "resource_usage_export_config_parameters" {
  default = null
}

variable "logging_service" {
}

variable "monitoring_service" {
}

variable "enable_legacy_abac" {
}

variable "worker_machine_type" {
}

variable "ft_machine_type" {
}

variable "image_type" {
}

variable "ng_disk_size_gb" {
}
variable "ft_disk_size_gb" {
}

variable "natgw_ip" {
}

variable "gcp_azs" {
  type = map(string)
  default = {
    us-east1     = "us-east1-c,us-east1-d"
    us-west1     = "us-west1-c,us-west1-a"
    us-central1  = "us-central1-c,us-central1-f"
    europe-west2 = "europe-west2-a,europe-west2-c"
    europe-west1 = "europe-west1-c,europe-west1-d"
  }
}

variable "ssh_key" {
}

variable "k8s_master_version" {
}

variable "k8s_node_version" {
}

variable "client_certificate" {
}

variable "k8s_zonal" {
}

variable "override_ft_name" {
}

variable "override_ng_name" {
}

variable "gke_map" {
}

variable "node_config" {
}

variable "workload_identity" {
}

variable "gke_auth" {
}

variable "network_policy" {
  default = false
}

variable "maintenance_window" {
  default = {
    recurrence = "FREQ=WEEKLY;BYDAY=SU"
    start_time = "2021-11-21T01:00:00Z"
    end_time   = "2021-11-21T18:00:00Z"
  }
}

variable "maintenance_exclusion" {
  default = {
    recurrence = ""
    start_time = ""
    end_time   = ""
    scope      =  ""
    exclusion_name = ""
  }
}

variable "jfrog_cluster_autoscaling" {
  default = {
    enabled = false
    autoscaling_profile = "BALANCED"
  }
}

variable "environment" {
  type = string
}

variable "narcissus_domain_short" {
  type = string
}

variable "default_tags" {
  type = map(string)
  default = {
    owner         = "devops"
    customer      = "shared"
    purpose       = "platform"
    workload_type = "main"
    application   = "all"
  }
}

variable "enable_tags" {
  type = bool
  default = false
}

variable "enable_intranode_visibility" {}
variable "create_stackstorm_rbac"{
  default = true
}