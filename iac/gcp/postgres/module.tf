resource "random_password" "pg_password" {
  count = 1
  length = 16
  special = true
  override_special = "_#%"
}

data "null_data_source" "auth_natgw_postgres_allowed" {
  count = length(split(";", var.natgw_ip))

  inputs = {
    name  = "natgw-${count.index + 1}"
    value = element(split(";", var.natgw_ip), count.index)
  }
}

# Instance CloudSQL
resource "google_sql_database_instance" "gcp_postgres" {
  count            = var.dbs_count
  name             = try(var.postgres_dbs[count.index]["name"], "${var.deploy_name}-${var.postgres_dbs[count.index]["name_postfix"]}")
  //  name             = "${var.deploy_name}-${var.postgres_dbs[count.index]["name_postfix"]}-${var.region}-${random_string.addon[0].result}"
  region           = var.region
  database_version = var.postgres_dbs[count.index]["database_version"]
  deletion_protection = lookup(var.postgres_dbs[count.index],"deletion_protection",false)

  settings {
    tier              = var.postgres_dbs[count.index]["machine_type"]
    disk_size         = var.postgres_dbs[count.index]["disk_size_gb"]
    disk_autoresize   = true
    availability_type = var.availability_type
    user_labels = data.null_data_source.gcp_postgres_tags[count.index].inputs
    dynamic "backup_configuration" {
      for_each = var.backup_configuration
      content {
        binary_log_enabled = lookup(backup_configuration.value, "binary_log_enabled", null)
        enabled            = lookup(backup_configuration.value, "enabled", null) #data.null_data_source.gcp_postgres_tags[count.index].inputs["application"] == "central" ? false : lookup(backup_configuration.value, "enabled", null)
        start_time         = lookup(backup_configuration.value, "start_time", null)
        location           = lookup(backup_configuration.value, "location", null) #var.central_backup_location == null &&  data.null_data_source.gcp_postgres_tags[count.index].inputs["application"] == "central" ? var.central_backup_location : 
        point_in_time_recovery_enabled = lookup(backup_configuration.value, "point_in_time_recovery_enabled", null)
        backup_retention_settings  {
          retained_backups  = lookup(backup_configuration.value, "retained_backups", 35)
          retention_unit   = lookup(backup_configuration.value, "retention_unit","COUNT")
        }
      }
    }
    dynamic "insights_config" { 
    for_each = var.insights_config != [] ? var.insights_config : []
    content {
            query_insights_enabled = lookup(insights_config.value, "query_insights_enabled", true)
            query_string_length = lookup(insights_config.value, "query_string_length", 1024)  
            record_application_tags= lookup(insights_config.value, "record_application_tags", false) 
            record_client_address= lookup(insights_config.value, "record_client_address", false)
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
      require_ssl      = lookup(var.postgres_dbs[count.index],"require_ssl",false)
      ipv4_enabled = var.postgres_dbs[count.index]["ipv4_enabled"]
      private_network = var.private_network
      dynamic "authorized_networks" {
        for_each = var.postgres_dbs[count.index]["ipv4_enabled"] == true ? concat(split(";", var.natgw_ip), var.authorized_networks_list) : []
        iterator = authorized_networks_list

        content {
          name  = "allow-${authorized_networks_list.key}"
          value = authorized_networks_list.value
        }
      }
    }
    dynamic "database_flags" {
      for_each = var.postgres_dbs[count.index]["database_flags_map"]
      iterator = database_flags_map

      content {
        name  = database_flags_map.key
        value = database_flags_map.value
      }
    }
  }
  lifecycle {
    ignore_changes = [
      #settings.0.replication_type, 
      settings.0.disk_size ##should be remove in 3 weeks##
      ]
  }
}

resource "google_sql_user" "pg_root_user" {
  count    = var.dbs_count
  name     = var.user_name
  instance = google_sql_database_instance.gcp_postgres[count.index].name
  password = var.user_password == "" ? random_password.pg_password[0].result : var.user_password
}


data "null_data_source" "gcp_postgres_tags" {
  count    = var.dbs_count
  inputs = {
    name          = lower("${var.deploy_name}-${var.postgres_dbs[count.index]["name_postfix"]}")
    machine_type  = lower(var.postgres_dbs[count.index]["machine_type"])
    db_cpu        = lower(element(split("-", var.postgres_dbs[count.index]["machine_type"]), 2))
    db_memory_mb  = lower(element(split("-", var.postgres_dbs[count.index]["machine_type"]), 3))
    db_storage_gb = lower(var.postgres_dbs[count.index]["disk_size_gb"])
    cloud_project = lower(var.project_name)
    environment   = lower(var.environment)
    jfrog_region  = lower(var.narcissus_domain_short)
    cloud_region  = lower(var.region)
    owner         = lower(contains(keys(var.postgres_dbs[count.index].tags), "owner") ? var.postgres_dbs[count.index].tags["owner"] : "devops")
    customer      = lower(contains(keys(var.postgres_dbs[count.index].tags), "customer") ? var.postgres_dbs[count.index].tags["customer"] : "shared")
    purpose       = lower(contains(keys(var.postgres_dbs[count.index].tags), "purpose") ? var.postgres_dbs[count.index].tags["purpose"] : "all-jfrog-apps")
    workload_type = lower(contains(keys(var.postgres_dbs[count.index].tags), "workload_type") ? var.postgres_dbs[count.index].tags["workload_type"] : "main")
    application   = lower(contains(keys(var.postgres_dbs[count.index].tags), "application") ? var.postgres_dbs[count.index].tags["application"] : "all")
  }
}


resource "sdm_resource" "postgres" {
  count = var.create_sdm_resources ? var.dbs_count : 0 
    postgres {
        name = "GCP-${lookup(var.postgres_dbs[count.index], "sdm_name",var.postgres_dbs[count.index].name_postfix)}"
        hostname = lookup(var.postgres_dbs[count.index],"sdm_hostname", google_sql_database_instance.gcp_postgres[count.index].private_ip_address)
        database = "postgres"
        username = lookup(var.postgres_dbs[count.index],"sdm_username", google_sql_user.pg_root_user[count.index].name)
        password = random_password.pg_password[0].result
        port = 5432
        tags = merge(lookup(var.postgres_dbs[count.index], "sdm_tags", null), {region=var.region}, {env = var.environment})
    }
}