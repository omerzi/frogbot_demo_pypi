data "google_client_config" "default" {
}

resource "google_storage_bucket" "default" {
  //  count         = "${var.module_enabled ? length(var.name) : 0}"
  //  name          = "${var.deploy_name}-${element(var.name, count.index)}"
  count         = var.module_enabled ? 1 : 0
  name          = var.deploy_name
  location      = length(var.location) > 0 ? var.location : data.google_client_config.default.region
  project       = length(var.project_name) > 0 ? var.project_name : data.google_client_config.default.project
  storage_class = var.storage_class
  force_destroy = var.force_destroy

  lifecycle_rule {
    action {
      type          = var.action_type
      storage_class = var.action_storage_class
    }

    condition {
      age                   = var.age
      created_before        = var.created_before
      with_state            = var.with_state
      matches_storage_class = var.matches_storage_class
      num_newer_versions    = var.num_newer_versions
    }
  }

  versioning {
    enabled = var.versioning_enabled
  }
}

resource "google_storage_bucket_acl" "default" {
  count       = length(var.role_entity) > 0 ? length(google_storage_bucket.default.*.name) : 0
  default_acl = var.default_acl
  bucket      = element(google_storage_bucket.default.*.name, count.index)

  role_entity = var.role_entity
}

