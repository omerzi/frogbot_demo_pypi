resource "random_string" "addon" {
  count   = var.module_enabled ? 1 : 0
  length  = 4
  special = false
  upper   = false
  number  = false
}

resource "random_string" "password" {
  count   = var.module_enabled ? 1 : 0
  length  = 16
  special = true
}

data "null_data_source" "auth_natgw_mysql_allowed" {
  count = var.module_enabled ? 2 : 0

  inputs = {
    name  = "natgw-${count.index + 1}"
    value = element(var.natgw_ip, count.index)
  }
}

# Master CloudSQL
resource "google_sql_database_instance" "new_instance_sql_master" {
  count            = var.module_enabled ? 1 : 0
  name             = "${var.deploy_name}-${var.service_name}-master-${var.region}-${random_string.addon[0].result}"
  region           = var.region
  database_version = var.database_version

  settings {
    tier              = var.machine_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    availability_type = "ZONAL"
    replication_type  = "SYNCHRONOUS"
    dynamic "backup_configuration" {
      for_each = var.backup_configuration
      content {
        binary_log_enabled = lookup(backup_configuration.value, "binary_log_enabled", null)
        enabled            = lookup(backup_configuration.value, "enabled", null)
        start_time         = lookup(backup_configuration.value, "start_time", null)
      }
    }
    dynamic "maintenance_window" {
      for_each = var.maintenance_window
      content {
        day          = lookup(maintenance_window.value, "day", null)
        hour         = lookup(maintenance_window.value, "hour", null)
        update_track = lookup(maintenance_window.value, "update_track", null)
      }
    }

    ip_configuration {
      dynamic "authorized_networks" {
        for_each = [data.null_data_source.auth_natgw_mysql_allowed.*.outputs]
        content {
          expiration_time = lookup(authorized_networks.value, "expiration_time", null)
          name            = lookup(authorized_networks.value, "name", null)
          value           = lookup(authorized_networks.value, "value", null)
        }
      }
    }
  }
}

# Replica CloudSQL
resource "google_sql_database_instance" "new_instance_sql_replica" {
  count                = var.module_enabled ? 1 : 0
  name                 = "${var.deploy_name}-${var.service_name}-replica-${var.region}-${random_string.addon[0].result}"
  region               = var.region
  database_version     = var.database_version
  master_instance_name = google_sql_database_instance.new_instance_sql_master[0].name

  replica_configuration {
    # connect_retry_interval = "${lookup(var.replica, "retry_interval", "60")}"
    failover_target = true
  }

  settings {
    tier              = var.machine_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    availability_type = "ZONAL"
    replication_type  = "SYNCHRONOUS"
    dynamic "maintenance_window" {
      for_each = var.maintenance_window
      content {
        day          = lookup(maintenance_window.value, "day", null)
        hour         = lookup(maintenance_window.value, "hour", null)
        update_track = lookup(maintenance_window.value, "update_track", null)
      }
    }
    crash_safe_replication = true

    ip_configuration {
      dynamic "authorized_networks" {
        for_each = [data.null_data_source.auth_natgw_mysql_allowed.*.outputs]
        content {
          expiration_time = lookup(authorized_networks.value, "expiration_time", null)
          name            = lookup(authorized_networks.value, "name", null)
          value           = lookup(authorized_networks.value, "value", null)
        }
      }
    }
  }
}

resource "random_id" "user-password" {
  count       = var.module_enabled ? 1 : 0
  byte_length = 8
}

resource "google_sql_user" "default" {
  count    = var.module_enabled ? 1 : 0
  name     = var.user_name
  instance = google_sql_database_instance.new_instance_sql_master[0].name
  password = var.user_password == "" ? random_string.password[0].result : var.user_password
}

