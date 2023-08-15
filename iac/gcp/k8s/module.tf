# Create new K8S cluster with autoscaling

data "google_container_engine_versions" "region" {
  location = var.region
}

resource "random_string" "admin-password" {
  count  = var.module_enabled ? 1 : 0
  length = 16

//  lifecycle {
//    ignore_changes = [
//      initial_node_count, master_authorized_networks_config
//    ]
//  }
}

# New K8s Cluster, if creation failed you'll need to cleanup manually before running again.
resource "google_container_cluster" "primary" {
  count                       = var.module_enabled ? 1 : 0
  provider                    = google-beta
  name                        = "${var.deploy_name}-${var.region}"
  location                    = var.k8s_zonal == "" ? var.region : var.region_zone
  min_master_version          = lookup(var.gke_map.override, "k8s_master_version", data.google_container_engine_versions.region.latest_master_version)
  network                     = var.network
  subnetwork                  = var.subnetwork
  logging_service             = var.logging_service
  monitoring_service          = var.monitoring_service
  enable_legacy_abac          = var.enable_legacy_abac
  enable_l4_ilb_subsetting    = lookup(var.gke_map.override, "enable_l4_ilb_subsetting",false)
  remove_default_node_pool    = "true"
  initial_node_count          = 1
  enable_shielded_nodes       = var.gke_auth.shielded_nodes
  enable_intranode_visibility = var.enable_intranode_visibility
  resource_labels             = data.null_data_source.cluster_tags.inputs


  master_auth {
   # username = var.gke_auth.basic_auth ? "basic-admin" : ""
   # password = var.gke_auth.basic_auth ? random_string.admin-password[0].result : ""

    client_certificate_config {
      issue_client_certificate = var.client_certificate
    }
  }


  dynamic "workload_identity_config" {
    for_each = var.workload_identity == null ? [] : [0]
    content {
      workload_pool = var.workload_identity == true ? "${var.project_name}.svc.id.goog" : ""
    }
  }

  network_policy {
    enabled   = var.network_policy
    provider  = var.network_policy ? "CALICO" : "PROVIDER_UNSPECIFIED"
  }

  cluster_autoscaling {
    enabled              = var.jfrog_cluster_autoscaling.enabled
    autoscaling_profile  = var.jfrog_cluster_autoscaling.autoscaling_profile
  }

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.subnet_cidr["k8s-private"]
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-private-range"
    services_secondary_range_name = "services-private-range"
  }

  maintenance_policy {
    recurring_window {
      recurrence = var.maintenance_window.recurrence
      start_time = var.maintenance_window.start_time
      end_time   = var.maintenance_window.end_time
    }
    maintenance_exclusion {
      end_time = var.maintenance_exclusion.end_time
      start_time = var.maintenance_exclusion.start_time
      exclusion_name = var.maintenance_exclusion.exclusion_name
      exclusion_options {
      scope = var.maintenance_exclusion.scope
      }
    }
  }
  # Authoroized networks allowed to access the Master

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.gke_map.override["public_access_cidrs"]
      iterator = authorized_network
      content {
        cidr_block = authorized_network.value.cidr_block
        display_name = authorized_network.value.display_name
      }
    }
  }

  dynamic "resource_usage_export_config" {
    for_each = toset(var.resource_usage_export_config_parameters != null ? ["exec"] : [])
    content {
      enable_network_egress_metering = lookup(var.resource_usage_export_config_parameters, "enable_network_egress_metering")
      enable_resource_consumption_metering = lookup(var.resource_usage_export_config_parameters, "enable_resource_consumption_metering")
      bigquery_destination {
        dataset_id = lookup(var.resource_usage_export_config_parameters, "bigquery_destination.dataset_id")
      }
    }
  }

  addons_config {
    network_policy_config {
      disabled = ! var.network_policy
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count, master_auth
    ]
  }
}

##### default node group (ng) paying customers #####
resource "google_container_node_pool" "worker" {
  count      = var.module_enabled ? 1 : 0
  name       = lookup(var.gke_map.ng, "name", "${var.deploy_name}-${var.region}-ng-1" )
  location   = var.k8s_zonal == "" ? var.region : var.region_zone
  cluster    = google_container_cluster.primary[0].name
  node_count = 1
  version    = lookup(var.gke_map.override, "k8s_node_version", data.google_container_engine_versions.region.latest_node_version)

  dynamic "autoscaling" {
    for_each = toset(var.autoscaling_parameters != null ? ["exec"] : [])
    content {
      min_node_count = lookup(var.autoscaling_parameters, "min_node_count")
      max_node_count = lookup(var.autoscaling_parameters, "max_node_count")
    }
  }
  management {
    auto_repair  = lookup(var.node_config, "node_auto_repair")
    auto_upgrade = lookup(var.node_config, "node_auto_upgrade" )
  }

  node_config {
    machine_type = lookup(var.gke_map.ng, "instance_type", "n2-highmem-16")
    image_type   = var.image_type
    disk_size_gb = lookup(var.gke_map.ng, "disk_size", "2000")
    disk_type    = lookup(var.gke_map.ng,"disk_type","pd-standard")
    labels = data.null_data_source.paying_node_pool_tags.inputs
    metadata     = {
      ssh-keys                 = var.ssh_key
      disable-legacy-endpoints = true
    }
    shielded_instance_config {
      enable_secure_boot = lookup(var.node_config, "enable_secure_boot" )
    }
    
    dynamic workload_metadata_config {
      for_each = var.workload_identity == null ? [] : [0]
      content {
      
      mode = var.workload_identity == true ? "GKE_METADATA" : "EXPOSE"
    }
    }

    oauth_scopes = var.override_oauth_scope != [] ? var.override_oauth_scope : var.oauth_scopes 

    tags = contains(keys(var.gke_map.ng), "instance_tags_override")  ? var.gke_map.ng["instance_tags_override"] :  var.instance_tags
  }
  lifecycle {
    ignore_changes = [
      node_count,
      autoscaling[0].max_node_count
    ]
  }
}

##### freetier (ft) node group #####
resource "google_container_node_pool" "freetier" {
  count      = contains(keys(var.gke_map), "ft")  ? 1 : 0
  name       = lookup(var.gke_map.ft, "name", "freetier-1" )
  location   = var.k8s_zonal == "" ? var.region : var.region_zone
  cluster    = google_container_cluster.primary[0].name
  node_count = 1
  version    = lookup(var.gke_map.override, "k8s_node_version", data.google_container_engine_versions.region.latest_node_version)

  management {
    auto_repair  = lookup(var.node_config, "node_auto_repair")
    auto_upgrade = lookup(var.node_config, "node_auto_upgrade" )
  }

  dynamic "autoscaling" {
    for_each = toset(var.autoscaling_parameters != null ? ["exec"] : [])
    content {
      min_node_count = lookup(var.autoscaling_parameters, "min_node_count")
      max_node_count = lookup(var.autoscaling_parameters, "max_node_count")
    }
  }

  node_config {
    machine_type = lookup(var.gke_map.ft, "instance_type", "n2-highmem-8")
    image_type   = var.image_type
    disk_size_gb = lookup(var.gke_map.ft, "disk_size", "1000")
    disk_type    = lookup(var.gke_map.ft,"disk_type","pd-standard")
    labels = data.null_data_source.free_tier_node_pool_tags.inputs

    shielded_instance_config {
      enable_secure_boot = lookup(var.node_config, "enable_secure_boot" )
    }
    taint {
      effect = "NO_SCHEDULE"
      key    = "subscription_type"
      value  = "free"
    }
    metadata     = {
      ssh-keys                 = var.ssh_key
      disable-legacy-endpoints = true
    }

    dynamic workload_metadata_config {
      for_each = var.workload_identity == null ? [] : [0]
      content {
      mode = var.workload_identity == true ? "GKE_METADATA" : "EXPOSE"
    }
    }

    oauth_scopes =  var.override_oauth_scope != [] ? var.override_oauth_scope : var.oauth_scopes 
    tags = contains(keys(var.gke_map.ft), "instance_tags_override")  ? var.gke_map.ft["instance_tags_override"] :  var.instance_tags
  }
  lifecycle {
    ignore_changes = [
      node_count,
      autoscaling[0].max_node_count
    ]
  }
}

##### xray-jobs (xj) node group #####
resource "google_container_node_pool" "xray-jobs" {
  count      = contains(keys(var.gke_map), "xj")  ? 1 : 0
  name       = lookup(var.gke_map.xj, "name", "xray-jobs-1" )
  location   = var.k8s_zonal == "" ? var.region : var.region_zone
  cluster    = google_container_cluster.primary[0].name
  node_count = 1
  version    = lookup(var.gke_map.override, "k8s_node_version", data.google_container_engine_versions.region.latest_node_version)

  management {
    auto_repair  = lookup(var.node_config, "node_auto_repair")
    auto_upgrade = lookup(var.node_config, "node_auto_upgrade" )
  }

  dynamic "autoscaling" {
    for_each = toset(var.autoscaling_parameters != null ? ["exec"] : [])
    content {
      min_node_count = lookup(var.autoscaling_parameters, "min_node_count")
      max_node_count = lookup(var.autoscaling_parameters, "max_node_count")
    }
  }

  node_config {
    machine_type = lookup(var.gke_map.xj, "instance_type", "n2-highmem-8")
    image_type   = var.image_type
    disk_size_gb = lookup(var.gke_map.xj, "disk_size", "1000")
    disk_type    = lookup(var.gke_map.xj,"disk_type","pd-standard")
    labels = data.null_data_source.xray_node_pool_tags[0].inputs
    shielded_instance_config {
      enable_secure_boot = lookup(var.node_config, "enable_secure_boot" )
    }
    taint {
      effect = "NO_SCHEDULE"
      key    = "app_type"
      value  = "xray-jobs"
    }
    metadata     = {
      ssh-keys                 = var.ssh_key
      disable-legacy-endpoints = true
    }

    dynamic workload_metadata_config {
      for_each = var.workload_identity == null ? [] : [0]
      content {
      mode = var.workload_identity == true ? "GKE_METADATA" : "EXPOSE"
    }
    }

      oauth_scopes = var.oauth_scopes
       
    tags = contains(keys(var.gke_map.xj), "instance_tags_override")  ? var.gke_map.xj["instance_tags_override"] :  var.instance_tags
    
  }
  lifecycle {
    ignore_changes = [
      node_count,
      autoscaling[0].max_node_count
    ]
  }
}

##### dedicated node group #####
resource "google_container_node_pool" "dedicated" {
  count      = contains(keys(var.gke_map), "dng")  ? 1 : 0
  name       = lookup(var.gke_map.dng, "name", "dng01" )
  location   = var.k8s_zonal == "" ? var.region : var.region_zone
  cluster    = google_container_cluster.primary[0].name
  node_count = 1
  version    = lookup(var.gke_map.override, "k8s_node_version", data.google_container_engine_versions.region.latest_node_version)

  management {
    auto_repair  = lookup(var.node_config, "node_auto_repair")
    auto_upgrade = lookup(var.node_config, "node_auto_upgrade" )
  }

  dynamic "autoscaling" {
    for_each = toset(var.autoscaling_parameters != null ? ["exec"] : [])
    content {
      min_node_count = lookup(var.autoscaling_parameters, "min_node_count")
      max_node_count = lookup(var.autoscaling_parameters, "max_node_count")
    }
  }

  node_config {
    machine_type = lookup(var.gke_map.dng, "instance_type", "n2-highmem-16")
    image_type   = var.image_type
    disk_size_gb = lookup(var.gke_map.dng, "disk_size", "1000")
    disk_type    = lookup(var.gke_map.dng,"disk_type","pd-ssd")
    labels = data.null_data_source.dedicated_node_pool_tags[0].inputs
    shielded_instance_config {
      enable_secure_boot = lookup(var.node_config, "enable_secure_boot" )
    }
    taint {
      effect = "NO_SCHEDULE"
      key    = "dedicated_customer_nodepool"
      value  = "broadcom"
    }
    metadata     = {
      ssh-keys                 = var.ssh_key
      disable-legacy-endpoints = true
    }

    dynamic workload_metadata_config {
      for_each = var.workload_identity == null ? [] : [0]
      content {
      mode = var.workload_identity == true ? "GKE_METADATA" : "EXPOSE"
    }
    }

      oauth_scopes = var.oauth_scopes
       
    tags = contains(keys(var.gke_map.dng), "instance_tags_override")  ? var.gke_map.dng["instance_tags_override"] :  var.instance_tags
    
  }
  lifecycle {
    ignore_changes = [
      node_count,
      autoscaling[0].max_node_count
    ]
  }
}


resource "google_container_node_pool" "nginxplus" {
  for_each = contains(keys(var.gke_map),"gke_pl_np") ? var.gke_map.gke_pl_np.nodes : {}
  name       = lookup(each.value,"name")
  location   = var.k8s_zonal == "" ? var.region : var.region_zone
  cluster    = google_container_cluster.primary[0].name
  node_count = 1
  version    = lookup(var.gke_map.override, "k8s_node_version", data.google_container_engine_versions.region.latest_node_version)

  dynamic "autoscaling" {
    for_each = toset(var.autoscaling_parameters != null ? ["exec"] : [])
    content {
      min_node_count = lookup(var.autoscaling_parameters, "min_node_count")
      max_node_count = lookup(var.autoscaling_parameters, "max_node_count")
    }
  }
  management {
    auto_repair  = lookup(var.node_config, "node_auto_repair")
    auto_upgrade = lookup(var.node_config, "node_auto_upgrade" )
  }

  node_config {
    machine_type = lookup(var.gke_map.gke_pl_np, "instance_type", "n2-standard-8")
    image_type   = var.image_type
    disk_size_gb = lookup(var.gke_map.gke_pl_np, "disk_size", "1000")
    disk_type    = lookup(var.gke_map.gke_pl_np,"disk_type","pd-ssd")
    labels = data.null_data_source.npx01_node_pool_tags[0].inputs
    metadata     = {
      ssh-keys                 = var.ssh_key
      disable-legacy-endpoints = true
    }
    shielded_instance_config {
      enable_secure_boot = lookup(var.node_config, "enable_secure_boot" )
    }
      taint {
      effect = "NO_SCHEDULE"
      key    = "privatelink"
      value  = "true"
    }
    dynamic workload_metadata_config {
      for_each = var.workload_identity == null ? [] : [0]
      content {
      
      mode = var.workload_identity == true ? "GKE_METADATA" : "EXPOSE"
    }
    }

    oauth_scopes = var.override_oauth_scope != [] ? var.override_oauth_scope : var.oauth_scopes 

    tags = contains(keys(each.value), "instance_tags_override")  ? each.value["instance_tags_override"] :  var.instance_tags
  }
  lifecycle {
    ignore_changes = [
      node_count,
      autoscaling[0].max_node_count
    ]
  }
}


# Create firewall rules for the instance-group functionallity.
resource "google_compute_firewall" "istio" {
  count = var.module_enabled ? 1 : 0
  name = "${var.deploy_name}-${var.region}-istio"
  network = var.network
  project = var.project_name

  allow {
    protocol  = "tcp"
    ports     = ["10250", "443", "15017","6443"]
  }
  source_ranges = [var.subnet_cidr["k8s-private"]]
}

resource "google_compute_firewall" "opa" {
  count = var.module_enabled ? 1 : 0
  name = "${var.deploy_name}-${var.region}-opa"
  network = var.network
  project = var.project_name

  allow {
    protocol  = "tcp"
    ports     = ["8443"]
  }
  source_ranges = [var.subnet_cidr["k8s-private"]]
}

data "null_data_source" "cluster_tags" {
  inputs = var. enable_tags ? merge(
    {
      cloud_project = var.project_name
      name          = "${var.deploy_name}-${var.region}"
      environment   = var.environment
      jfrog_region  = var.narcissus_domain_short
      cloud_region  = var.region
      wizexclude    = ""
      k8s_version   = lookup(var.gke_map.override, "k8s_version")

    },
      contains(keys(var.gke_map.override), "tags") ? merge(var.default_tags, var.gke_map.override.tags) : var.default_tags 
    ) : {}
}


data "null_data_source" "free_tier_node_pool_tags" {
  inputs = var.enable_tags ? merge(
    {
      "k8s.jfrog.com/cloud_project"     = lower(var.project_name)
      "k8s.jfrog.com/node_group_name"   = lower(lookup(var.gke_map.ft, "name", "freetier-1" ))
      "k8s.jfrog.com/environment"       = lower(var.environment)
      "k8s.jfrog.com/jfrog_region"      = lower(var.narcissus_domain_short)
      "k8s.jfrog.com/cloud_region"      = lower(var.region)
      "k8s.jfrog.com/owner"             = lower(contains(keys(var.gke_map.ft.labels), "k8s.jfrog.com/owner") ? var.gke_map.ft.labels["k8s.jfrog.com/owner"] : "devops")
      "k8s.jfrog.com/customer"          = lower(contains(keys(var.gke_map.ft.labels), "k8s.jfrog.com/customer") ? var.gke_map.ft.labels["k8s.jfrog.com/customer"] : "shared-free-tier-customers")
      "k8s.jfrog.com/subscription_type" = lower(contains(split("-", var.deploy_name), "gcoss") ? null : "free")
      "k8s.jfrog.com/purpose"           = lower(contains(keys(var.gke_map.ft.labels), "k8s.jfrog.com/purpose") ? var.gke_map.ft.labels["k8s.jfrog.com/purpose"] : "compute")
      "k8s.jfrog.com/workload_type"     = lower(contains(keys(var.gke_map.ft.labels), "k8s.jfrog.com/workload_type") ? var.gke_map.ft.labels["k8s.jfrog.com/workload_type"] : "main")
      "k8s.jfrog.com/application"       = lower(contains(keys(var.gke_map.ft.labels), "k8s.jfrog.com/application") ? var.gke_map.ft.labels["k8s.jfrog.com/application"]: "all")
      "k8s.jfrog.com/instance_type"     = lower(contains(keys(var.gke_map.ft), "instance_type") ? "n2-highmem-8" : lookup(var.gke_map.ng, "instance_type"))
      "k8s.jfrog.com/disk_size"         = lower(contains(keys(var.gke_map.ft), "disk_size") ? "1000" : lookup(var.gke_map.ft, "disk_size"))
      "k8s.jfrog.com/disk_type"         = lower(try(var.gke_map.ft["volume_type"], "pd-ssd"))
    
    },
      merge(contains(keys(var.gke_map.override), "tags") ? var.gke_map.override.tags : {} , var.gke_map.ft.labels)
    ) : {"k8s.jfrog.com/subscription_type" = "free"}
}

data "null_data_source" "paying_node_pool_tags" {
  inputs = var.enable_tags ? merge(
    {
      "k8s.jfrog.com/cloud_project"     = lower(var.project_name)
      "k8s.jfrog.com/node_group_name"   = lower(lookup(var.gke_map.ng, "name", "${var.deploy_name}-${var.region}-ng-1" ))
      "k8s.jfrog.com/environment"       = lower(var.environment)
      "k8s.jfrog.com/jfrog_region"      = lower(var.narcissus_domain_short)
      "k8s.jfrog.com/cloud_region"      = lower(var.region)
      "k8s.jfrog.com/owner"             = lower(contains(keys(var.gke_map.ng.labels), "k8s.jfrog.com/owner") ? var.gke_map.ng.labels["k8s.jfrog.com/owner"] : "devops")
      "k8s.jfrog.com/customer"          = lower(contains(keys(var.gke_map.ng.labels), "k8s.jfrog.com/customer") ? var.gke_map.ng.labels["k8s.jfrog.com/customer"] : "shared-paying-customers")
      "k8s.jfrog.com/subscription_type" = lower(contains(split("-", var.deploy_name), "gcoss") ? "open-source-free" : "paying")
      "k8s.jfrog.com/purpose"           = lower(contains(keys(var.gke_map.ng.labels), "k8s.jfrog.com/purpose") ? var.gke_map.ng.labels["k8s.jfrog.com/purpose"] : "compute")
      "k8s.jfrog.com/workload_type"     = lower(contains(keys(var.gke_map.ng.labels), "k8s.jfrog.com/workload_type") ? var.gke_map.ng.labels["k8s.jfrog.com/workload_type"] : "main")
      "k8s.jfrog.com/application"       = lower(contains(keys(var.gke_map.ng.labels), "k8s.jfrog.com/application") ? var.gke_map.ng.labels["k8s.jfrog.com/application"]: "all")
      "k8s.jfrog.com/instance_type"     = lower(contains(keys(var.gke_map.ng), "instance_type") ? "n2-highmem-16" : lookup(var.gke_map.ng, "instance_type"))
      "k8s.jfrog.com/disk_size"         = lower(contains(keys(var.gke_map.ng), "disk_size") ? "2000" : lookup(var.gke_map.ng, "disk_size"))
      "k8s.jfrog.com/disk_type"         = lower(try(var.gke_map.ng["volume_type"], "pd-ssd"))
    },
      merge(contains(keys(var.gke_map.override), "tags") ? var.gke_map.override.tags : {} , var.gke_map.ng.labels)
    # If k8s version <1.19, only label is subscription type
    ) : {"k8s.jfrog.com/subscription_type" = contains(split("-", var.deploy_name), "gcoss") ? null : "paying"}

}

data "null_data_source" "xray_node_pool_tags" {
  count = contains(keys(var.gke_map), "xj")  ? 1 : 0
  inputs = var.enable_tags ? merge(
    {
      "k8s.jfrog.com/cloud_project"     = lower(var.project_name)
      "k8s.jfrog.com/node_group_name"   = lower(lookup(var.gke_map.xj, "name", "${var.deploy_name}-${var.region}-xray-1" ))
      "k8s.jfrog.com/environment"       = lower(var.environment)
      "k8s.jfrog.com/jfrog_region"      = lower(var.narcissus_domain_short)
      "k8s.jfrog.com/cloud_region"      = lower(var.region)
      "k8s.jfrog.com/owner"             = lower(contains(keys(var.gke_map.xj.labels), "k8s.jfrog.com/owner") ? var.gke_map.xj.labels["k8s.jfrog.com/owner"] : "devops")
      "k8s.jfrog.com/customer"          = lower(contains(keys(var.gke_map.xj.labels), "k8s.jfrog.com/customer") ? var.gke_map.xj.labels["k8s.jfrog.com/customer"] : "shared-xray-on-demand")
      "k8s.jfrog.com/app_type"          = lower(contains(keys(var.gke_map.xj.labels), "k8s.jfrog.com/app_type") ? var.gke_map.xj.labels["k8s.jfrog.com/app_type"] : "xray-jobs")
      "k8s.jfrog.com/purpose"           = lower(contains(keys(var.gke_map.xj.labels), "k8s.jfrog.com/purpose") ? var.gke_map.xj.labels["k8s.jfrog.com/purpose"] : "compute")
      "k8s.jfrog.com/workload_type"     = lower(contains(keys(var.gke_map.xj.labels), "k8s.jfrog.com/workload_type") ? var.gke_map.xj.labels["k8s.jfrog.com/workload_type"] : "main")
      "k8s.jfrog.com/application"       = lower(contains(keys(var.gke_map.xj.labels), "k8s.jfrog.com/application") ? var.gke_map.xj.labels["k8s.jfrog.com/application"]: "xray")
      "k8s.jfrog.com/instance_type"     = lower(contains(keys(var.gke_map.xj), "instance_type") ? "n2-highmem-16" : lookup(var.gke_map.xj, "instance_type"))
      "k8s.jfrog.com/disk_size"         = lower(contains(keys(var.gke_map.xj), "disk_size") ? "2000" : lookup(var.gke_map.xj, "disk_size"))
      "k8s.jfrog.com/disk_type"         = lower(try(var.gke_map.xj["volume_type"], "pd-ssd"))
    },
      merge(contains(keys(var.gke_map.override), "tags") ? var.gke_map.override.tags : {} , var.gke_map.xj.labels)
    ) : {"k8s.jfrog.com/app_type" = "xray-jobs"}
}
data "null_data_source" "dedicated_node_pool_tags" {
  count = contains(keys(var.gke_map), "dng")  ? 1 : 0
  inputs = var.enable_tags ? merge(
    {
      "k8s.jfrog.com/cloud_project"               = lower(var.project_name)
      "k8s.jfrog.com/node_group_name"             = lower(lookup(var.gke_map.dng, "name", "${var.deploy_name}-${var.region}-dng-1" ))
      "k8s.jfrog.com/environment"                 = lower(var.environment)
      "k8s.jfrog.com/jfrog_region"                = lower(var.narcissus_domain_short)
      "k8s.jfrog.com/cloud_region"                = lower(var.region)
      "k8s.jfrog.com/owner"                       = lower(contains(keys(var.gke_map.dng.labels), "k8s.jfrog.com/owner") ? var.gke_map.dng.labels["k8s.jfrog.com/owner"] : "devops")
      "k8s.jfrog.com/dedicated_customer_nodepool" = lower(contains(keys(var.gke_map.dng.labels), "k8s.jfrog.com/dedicated_customer_nodepool") ? var.gke_map.dng.labels["k8s.jfrog.com/dedicated_customer_nodepool"] : "broadcom")
      "k8s.jfrog.com/customer"                    = lower(contains(keys(var.gke_map.dng.labels), "k8s.jfrog.com/customer") ? var.gke_map.dng.labels["k8s.jfrog.com/customer"] : "dedicated-on-demand")
      "k8s.jfrog.com/purpose"                     = lower(contains(keys(var.gke_map.dng.labels), "k8s.jfrog.com/purpose") ? var.gke_map.dng.labels["k8s.jfrog.com/purpose"] : "compute")
      "k8s.jfrog.com/workload_type"               = lower(contains(keys(var.gke_map.dng.labels), "k8s.jfrog.com/workload_type") ? var.gke_map.dng.labels["k8s.jfrog.com/workload_type"] : "main")
      "k8s.jfrog.com/application"                 = lower(contains(keys(var.gke_map.dng.labels), "k8s.jfrog.com/application") ? var.gke_map.dng.labels["k8s.jfrog.com/application"]: "all")
      "k8s.jfrog.com/instance_type"               = lower(contains(keys(var.gke_map.dng), "instance_type") ? "n2-highmem-16" : lookup(var.gke_map.dng, "instance_type"))
      "k8s.jfrog.com/disk_size"                   = lower(contains(keys(var.gke_map.dng), "disk_size") ? "1000" : lookup(var.gke_map.dng, "disk_size"))
      "k8s.jfrog.com/disk_type"                   = lower(try(var.gke_map.dng["disk_type"], "pd-ssd"))
    },
      merge(contains(keys(var.gke_map.override), "tags") ? var.gke_map.override.tags : {} , var.gke_map.dng.labels)
    ) : {"k8s.jfrog.com/dedicated_customer_nodepool" = "broadcom"}
}
data "null_data_source" "npx01_node_pool_tags" {
  count = contains(keys(var.gke_map), "gke_pl_np")  ? 1 : 0
  inputs = var.enable_tags ? merge(
    {
    "k8s.jfrog.com/cloud_project" = lower(var.project_name)
    "k8s.jfrog.com/jfrog_region"  = lower(var.narcissus_domain_short)
    "k8s.jfrog.com/environment"   = lower(var.environment)
    "k8s.jfrog.com/cloud_region"  = lower(var.region)
    "k8s.jfrog.com/owner"         = "devops"
    "k8s.jfrog.com/purpose"       = "privatelink"
    "k8s.jfrog.com/workload_type" = "nginxplus"
    "k8s.jfrog.com/application"   = "all"
    "k8s.jfrog.com/privatelink"   = "true"
    "k8s.jfrog.com/customer"      = "internal"
    "k8s.jfrog.com/instance_type" = lower(contains(keys(var.gke_map.gke_pl_np), "instance_type") ? var.gke_map.gke_pl_np.instance_type : "n2-standard-8" )
    },
      merge(contains(keys(var.gke_map.gke_pl_np), "tags") ? var.gke_map.gke_pl_np.tags : {} )
    ) : {"k8s.jfrog.com/privatelink" = "true"}
}

