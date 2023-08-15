resource "google_filestore_instance" "instance" {
  provider = google-beta
  count = var.module_enabled ? 1 : 0
  name  = "${var.deploy_name}-${var.region}"
  zone  = var.region_zone
  tier  = "STANDARD"
  labels  = data.null_data_source.gcp_filestore_tags[count.index].inputs

  file_shares {
    capacity_gb = var.disk_size_gb
    name        = "vol1"
  }

  networks {
    network = var.vpc_self_link
    modes   = ["MODE_IPV4"]
  }
}

data "null_data_source" "gcp_filestore_tags" {
  count    = var.module_enabled ? 1 : 0
  inputs = {
    cloud_project = lower(var.project_name)
    name          = lower("${var.deploy_name}-${var.region}")
    capacity_gb   = lower(var.disk_size_gb)
    environment   = lower(var.environment)
    jfrog_region  = lower(var.narcissus_domain_short)
    cloud_region  = lower(var.region)
    owner         = lower(contains(keys(var.filestore_tags), "owner") ? var.filestore_tags["owner"] : "devops")
    customer      = lower(contains(keys(var.filestore_tags), "customer") ? var.filestore_tags["customer"] : "shared")
    purpose       = lower(contains(keys(var.filestore_tags), "purpose") ? var.filestore_tags["purpose"] : "all-jfrog-apps")
    workload_type = lower(contains(keys(var.filestore_tags), "workload_type") ? var.filestore_tags["workload_type"] : "main")
    application   = lower(contains(keys(var.filestore_tags), "application") ? var.filestore_tags["application"]: "all")
  }
}

