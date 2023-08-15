data "template_file" "startup-script" {
  template = file("${path.module}/files/${var.service_name}_bootstrap.sh")

  vars = {
    mmsGroupId = var.mmsGroupId
    mmsApiKey  = var.mmsApiKey
  }
}

resource "google_compute_instance_template" "default" {
  count       = var.module_enabled ? 1 : 0
  project     = var.project_name
  name_prefix = "default-"

  machine_type = var.machine_type

  region = var.region
  tags = [var.instance_tags]

  labels = var.instance_labels

  network_interface {
    network    = var.subnetwork == "" ? var.network : ""
    subnetwork = var.subnetwork
    dynamic "access_config" {
      for_each = [var.access_config]
      content {
        nat_ip       = lookup(access_config.value, "nat_ip", null)
        network_tier = lookup(access_config.value, "network_tier", null)
      }
    }
    network_ip         = var.network_ip
    subnetwork_project = var.subnetwork_project == "" ? var.project_name : var.subnetwork_project
  }

  can_ip_forward = var.can_ip_forward

  disk {
    auto_delete  = var.disk_auto_delete
    boot         = true
    source_image = var.compute_image
    type         = "PERSISTENT"
    disk_type    = var.disk_type
    disk_size_gb = var.boot_disk_size_gb
    mode         = var.mode
  }

  disk {
    auto_delete  = var.disk_auto_delete
    boot         = false
    type         = "PERSISTENT"
    disk_type    = var.disk_type
    disk_size_gb = var.data_disk_size_gb
    mode         = var.mode
  }

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  metadata = merge(
    {
      "startup-script" = data.template_file.startup-script.rendered
      "tf_depends_id"  = var.depends_id
      "ssh-keys"       = var.ssh_key
    },
    var.metadata,
  )

  scheduling {
    preemptible       = var.preemptible
    automatic_restart = var.automatic_restart
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "default" {
  count              = var.module_enabled && var.zonal ? 1 : 0
  project            = var.project_name
  name               = "${var.deploy_name}-${var.region}"
  description        = "compute VM Instance Group"
  wait_for_instances = var.wait_for_instances

  base_instance_name = "${var.deploy_name}-${var.region}"

  version {
    instance_template = google_compute_instance_template.default[0].self_link
  }
  zone = var.region_zone

//  update_strategy = var.update_strategy

  dynamic "update_policy" {
    for_each = [var.rolling_update_policy]
    content {
      max_surge_fixed         = lookup(update_policy.value, "max_surge_fixed", null)
      max_surge_percent       = lookup(update_policy.value, "max_surge_percent", null)
      max_unavailable_fixed   = lookup(update_policy.value, "max_unavailable_fixed", null)
      max_unavailable_percent = lookup(update_policy.value, "max_unavailable_percent", null)
      min_ready_sec           = lookup(update_policy.value, "min_ready_sec", null)
      minimal_action          = update_policy.value.minimal_action
      type                    = update_policy.value.type
    }
  }

  target_pools = var.target_pools

  // There is no way to unset target_size when autoscaling is true so for now, jsut use the min_replicas value.
  // Issue: https://github.com/terraform-providers/terraform-provider-google/issues/667
  target_size = var.autoscaling ? var.min_replicas : var.instance_count

  named_port {
    name = var.service_port_name
    port = var.service_port
  }

  auto_healing_policies {
    health_check = var.http_health_check ? element(
      concat(
        google_compute_health_check.mig-health-check.*.self_link,
        [""],
      ),
      0,
    ) : ""
    initial_delay_sec = var.hc_initial_delay
  }

  provisioner "local-exec" {
    when    = destroy
    command = var.local_cmd_destroy
  }

  provisioner "local-exec" {
    when    = create
    command = var.local_cmd_create
  }
}

resource "google_compute_autoscaler" "default" {
  count   = var.module_enabled && var.autoscaling && var.zonal ? 1 : 0
  name    = "${var.deploy_name}-${var.region}"
  zone    = var.region_zone
  project = var.project_name
  target  = google_compute_instance_group_manager.default[0].self_link

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.cooldown_period
    dynamic "cpu_utilization" {
      for_each = [var.autoscaling_cpu]
      content {
        target = lookup(cpu_utilization.value, "target", null)
      }
    }
    dynamic "metric" {
      for_each = [var.autoscaling_metric]
      content {
        name   = lookup(metric.value, "name", null)
        target = lookup(metric.value, "target", null)
        type   = lookup(metric.value, "type", null)
      }
    }
    dynamic "load_balancing_utilization" {
      for_each = [var.autoscaling_lb]
      content {
        target = lookup(load_balancing_utilization.value, "target", null)
      }
    }
  }
}

data "google_compute_zones" "available" {
  project = var.project_name
  region  = var.region
}

locals {
  distribution_zones = {
    default = [data.google_compute_zones.available.names]
    user    = [var.distribution_policy_zones]
  }

  dependency_id = element(
    concat(null_resource.region_dummy_dependency.*.id, ["disabled"]),
    0,
  )
}

resource "google_compute_region_instance_group_manager" "default" {
  count              = var.module_enabled && false == var.zonal ? 1 : 0
  project            = var.project_name
  name               = "${var.deploy_name}-${var.region}"
  description        = "compute VM Instance Group"
  wait_for_instances = var.wait_for_instances

  base_instance_name = "${var.deploy_name}-${var.region}"
  version {
    instance_template = google_compute_instance_template.default[0].self_link
  }
  region = var.region

//  update_strategy = var.update_strategy

  dynamic "update_policy" {
    for_each = [var.rolling_update_policy]
    content {
      max_surge_fixed         = lookup(update_policy.value, "max_surge_fixed", null)
      max_surge_percent       = lookup(update_policy.value, "max_surge_percent", null)
      max_unavailable_fixed   = lookup(update_policy.value, "max_unavailable_fixed", null)
      max_unavailable_percent = lookup(update_policy.value, "max_unavailable_percent", null)
      min_ready_sec           = lookup(update_policy.value, "min_ready_sec", null)
      minimal_action          = update_policy.value.minimal_action
      type                    = update_policy.value.type
    }
  }

  distribution_policy_zones = [local.distribution_zones[length(var.distribution_policy_zones) == 0 ? "default" : "user"]]

  target_pools = var.target_pools

  // There is no way to unset target_size when autoscaling is true so for now, jsut use the min_replicas value.
  // Issue: https://github.com/terraform-providers/terraform-provider-google/issues/667
  target_size = var.autoscaling ? var.min_replicas : var.instance_count

  auto_healing_policies {
    health_check = var.http_health_check ? element(
      concat(
        google_compute_health_check.mig-health-check.*.self_link,
        [""],
      ),
      0,
    ) : ""
    initial_delay_sec = var.hc_initial_delay
  }

  named_port {
    name = var.service_port_name
    port = var.service_port
  }

  provisioner "local-exec" {
    when    = destroy
    command = var.local_cmd_destroy
  }

  provisioner "local-exec" {
    when    = create
    command = var.local_cmd_create
  }

  // Initial instance verification can take 10-15m when a health check is present.
  timeouts {
    create = var.http_health_check ? "15m" : "5m"
  }
}

resource "google_compute_region_autoscaler" "default" {
  count   = var.module_enabled && var.autoscaling && false == var.zonal ? 1 : 0
  name    = "${var.deploy_name}-${var.region}"
  region  = var.region
  project = var.project_name
  target  = google_compute_region_instance_group_manager.default[0].self_link

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.cooldown_period
    dynamic "cpu_utilization" {
      for_each = [var.autoscaling_cpu]
      content {
        target = lookup(cpu_utilization.value, "target", null)
      }
    }
    dynamic "metric" {
      for_each = [var.autoscaling_metric]
      content {
        name   = lookup(metric.value, "name", null)
        target = lookup(metric.value, "target", null)
        type   = lookup(metric.value, "type", null)
      }
    }
    dynamic "load_balancing_utilization" {
      for_each = [var.autoscaling_lb]
      content {
        target = lookup(load_balancing_utilization.value, "target", null)
      }
    }
  }
}

resource "null_resource" "dummy_dependency" {
  count      = var.module_enabled && var.zonal ? 1 : 0
  depends_on = [google_compute_instance_group_manager.default]

  triggers = {
    instance_template = element(google_compute_instance_template.default.*.self_link, 0)
  }
}

resource "null_resource" "region_dummy_dependency" {
  count      = var.module_enabled && false == var.zonal ? 1 : 0
  depends_on = [google_compute_region_instance_group_manager.default]

  triggers = {
    instance_template = element(google_compute_instance_template.default.*.self_link, 0)
  }
}

resource "google_compute_firewall" "default-ssh" {
  count   = var.module_enabled && var.ssh_fw_rule ? 1 : 0
  project = var.subnetwork_project == "" ? var.project_name : var.subnetwork_project
  name    = "${var.deploy_name}-${var.region}-vm-ssh"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["allow-ssh"]
}

resource "google_compute_health_check" "mig-health-check" {
  count   = var.module_enabled && var.http_health_check ? 1 : 0
  name    = "${var.deploy_name}-${var.region}"
  project = var.project_name

  check_interval_sec  = var.hc_interval
  timeout_sec         = var.hc_timeout
  healthy_threshold   = var.hc_healthy_threshold
  unhealthy_threshold = var.hc_unhealthy_threshold

  http_health_check {
    port         = var.hc_port == "" ? var.service_port : var.hc_port
    request_path = var.hc_path
  }
}

resource "google_compute_firewall" "mig-health-check" {
  count   = var.module_enabled && var.http_health_check ? 1 : 0
  project = var.subnetwork_project == "" ? var.project_name : var.subnetwork_project
  name    = "${var.deploy_name}-${var.region}-vm-hc"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = [var.hc_port == "" ? var.service_port : var.hc_port]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = var.target_tags
}

data "google_compute_instance_group" "zonal" {
  count   = var.module_enabled && var.zonal ? 1 : 0
  zone    = var.region_zone
  project = var.project_name

  // Use the dependency id which is recreated whenever the instance template changes to signal when to re-read the data source.
  name = element(
    split(
      "|",
      "${local.dependency_id}|${element(
        concat(
          google_compute_instance_group_manager.default.*.name,
          ["unused"],
        ),
        0,
      )}",
    ),
    1,
  )
}

# Create firewall rules for the instance-group functionallity.
resource "google_compute_firewall" "default" {
  count   = var.module_enabled ? 1 : 0
  name    = "${var.deploy_name}-${var.region}"
  network = var.network
  project = var.project_name

  allow {
    protocol = "all"
  }

  source_tags = var.source_tags
  target_tags = var.target_tags
}

