# instance creation including route and firewall rule

resource "google_compute_address" "sshproxy" {
  count   = var.module_enabled ? lookup(var.sshproxy_map, "instance_count" ) : 0
  name    = lookup(var.sshproxy_map, "ext_ip_name", "${var.deploy_name}-sshproxy-${var.region}-${count.index}")
  address = ""
}

data "template_file" "sshproxy-startup-script" {
  count   = var.module_enabled ? lookup(var.sshproxy_map, "instance_count" ) : 0
  template = file("${path.module}/files/sshproxy_bootstrap.sh")
  vars = {
//    gateway_token = lookup(data.terraform_remote_state.gcp-pipelines-sdm.outputs, "sdm-${var.environment}-${var.region}")[count.index]
//    gateway_token = google_secret_manager_secret_version.sdm-token[count.index].secret_data
  }
}

resource "google_compute_disk" "sshproxy" {
  count = var.module_enabled ? lookup(var.sshproxy_map, "instance_count" ) : 0
  name  = lookup(var.sshproxy_map, "name", "${var.deploy_name}-sshproxy-${var.region}-${count.index}")
  type  = lookup(var.sshproxy_map, "disk_type" , "pd-standard")
  size  = lookup(var.sshproxy_map, "disk_size_gb" )
  labels = {
    environment = var.environment
  }
  lifecycle {
    ignore_changes = [
      snapshot
    ]
  }
}


resource "google_service_account" "ssh_proxy" {
  account_id   = "ssh-proxy-sa-${var.region}"
  display_name = "ssh-proxy-sa-${var.region}"
}

resource "google_compute_instance" "sshproxy" {
  count        = var.module_enabled ? lookup(var.sshproxy_map, "instance_count" ) : 0
  name         = lookup(var.sshproxy_map, "name", "${var.deploy_name}-sshproxy-${var.region}-${count.index}")
  machine_type = lookup(var.sshproxy_map, "machine_type" )
  allow_stopping_for_update = true
  can_ip_forward            = lookup(var.sshproxy_map, "can_ip_forward" , false)

  #zone         = "${element(var.var_zones, count.index)}"
  tags = lookup(var.sshproxy_map, "instance_tags" )
  boot_disk {
    initialize_params {
      image =lookup(var.sshproxy_map, "compute_image","ubuntu-2204-lts")
      size = lookup(var.sshproxy_map, "disk_size_gb","50")
    }
  }
  labels = {
    environment = var.environment
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_key} ubuntu"
    block-project-ssh-keys = true
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.ssh_proxy.email
    scopes = []
  }

  metadata_startup_script = data.template_file.sshproxy-startup-script[count.index].rendered
  network_interface {
    subnetwork = var.subnetwork
    access_config {
      nat_ip = element(
        concat(google_compute_address.sshproxy.*.address, [""]),
        count.index,
      )
    }
  }
  lifecycle {
    ignore_changes = [
    metadata_startup_script, boot_disk[0].initialize_params, service_account , network_interface[0].subnetwork
    ]
  }
}


resource "google_compute_firewall" "sshproxy" {
  count   = var.module_enabled ? 1 : 0
  name    = "${var.deploy_name}-sshproxy-${var.region}-vm-ssh"
  network = var.network

  log_config {
      metadata = "INCLUDE_ALL_METADATA"
  }
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = lookup(var.sshproxy_map, "protocol" )
    ports    = lookup(var.sshproxy_map, "ports" )
  }

  source_ranges = lookup(var.sshproxy_map, "ssh_source_ranges" )
  target_tags = lookup(var.sshproxy_map, "target_tags" )
}

resource "google_compute_firewall" "sdm" {
  count   = var.module_enabled && contains(keys(var.sshproxy_map),"sdm_source_ranges") ? 1 : 0
  name    = "${var.deploy_name}-sdm-${var.region}-vm-ssh"
  network = var.network

  log_config {
      metadata = "INCLUDE_ALL_METADATA"
  }
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = lookup(var.sshproxy_map, "protocol" )
    ports    = lookup(var.sshproxy_map, "sdm_ports" )
  }

  source_ranges = lookup(var.sshproxy_map, "sdm_source_ranges" )
  target_tags = lookup(var.sshproxy_map, "target_tags" )
}