locals {
  privatelink_labels = {
    "k8s.jfrog.com/jfrog_region"  = lower(var.narcissus_domain_short)
    "k8s.jfrog.com/project_name"  = lower(var.cloud_subscription)
    "k8s.jfrog.com/environment"   = lower(var.environment)
    "k8s.jfrog.com/cloud_region"  = lower(var.region)
    "k8s.jfrog.com/owner"         = "devops"
    "k8s.jfrog.com/purpose"       = "privatelink"
    "k8s.jfrog.com/workload_type" = "nginxplus"
    "k8s.jfrog.com/application"   = "all"
    "k8s.jfrog.com/privatelink"   = "true"
    "k8s.jfrog.com/customer"      = "internal"
    "k8s.jfrog.com/instance_type" = try(var.privatelink_map.dedicated_nodepool["instance_type"], "")
  }
  privatelink_tags = {
    "jfrog_region"  = lower(var.narcissus_domain_short)
    "project_name"  = lower(var.cloud_subscription)
    "environment"   = lower(var.environment)
    "cloud_region"  = lower(var.region)
    "owner"         = "devops"
    "purpose"       = "privatelink"
    "workload_type" = "nginxplus"
    "application"   = "all"
    "privatelink"   = "true"
    "customer"      = "internal"
    "instance_type" = try(var.privatelink_map.dedicated_nodepool["instance_type"], "")
  }
}