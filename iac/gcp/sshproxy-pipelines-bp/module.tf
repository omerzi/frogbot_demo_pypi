data "terraform_remote_state" "gcp-pipelines-sdm" {
  backend = "s3"
  workspace = "ALL"
  config = {
    bucket  = "jfrog-infra-terraform-state"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    profile        = "Devops-infra"
    workspace_key_prefix = "sdm"
    encrypt = true
  }
  }

data "terraform_remote_state" "gcp-pipelines-usw1" {
  backend = "s3"
  workspace = "pipelines-bp-prod-us-west1"
  config = {
    bucket  = "jfrog-infra-terraform-state"
    key  = "Net"
    region = "us-east-1"
    profile        = "Devops-infra"
    workspace_key_prefix = "gcp"
  }
}
data "terraform_remote_state" "gcp-pipelines-usc1" {
  backend = "s3"
  workspace = "pipelines-bp-prod-us-central1"
  config = {
    bucket  = "jfrog-infra-terraform-state"
    key  = "Net"
    region = "us-east-1"
    profile        = "Devops-infra"
    workspace_key_prefix = "gcp"
  }
}
data "terraform_remote_state" "gcp-pipelines-euw2" {
  backend = "s3"
  workspace = "pipelines-bp-prod-europe-west2"
  config = {
    bucket  = "jfrog-infra-terraform-state"
    key  = "Net"
    region = "us-east-1"
    profile        = "Devops-infra"
    workspace_key_prefix = "gcp"
  }
}
data "terraform_remote_state" "gcp-pipelines-ape2" {
  backend = "s3"
  workspace = "pipelines-bp-prod-asia-east2"
  config = {
    bucket  = "jfrog-infra-terraform-state"
    key  = "Net"
    region = "us-east-1"
    profile        = "Devops-infra"
    workspace_key_prefix = "gcp"
  }
}


data "terraform_remote_state" "gcp-pipelines-stg-use1" {
  backend = "s3"
  workspace = "pipelines-bp-stg-us-east1"
  config = {
    bucket  = "jfrog-infra-terraform-state"
    key  = "Net"
    region = "us-east-1"
    profile        = "Devops-infra"
    workspace_key_prefix = "gcp"
  }
}
# data "terraform_remote_state" "gcp-pipelines-dev-euw1" {
#   backend = "gcs"
#   workspace = "pipelines-bp-dev-europe-west1"
#   config = {
#     bucket  = "terraform-state-pipelines-cloud-dev"
#     key  = "Net"
#   }
# }


# Create a secret for sdm token
resource "google_secret_manager_secret" "sdm-token" {
  count   = var.module_enabled ? var.instance_count : 0
  provider = google-beta

  secret_id = "sdm-${var.deploy_name}-${var.region}-${count.index}"
  replication {
    automatic = true
  }
}
# Add the secret data for sdm token
resource "google_secret_manager_secret_version" "sdm-token" {
  count   = var.module_enabled ? var.instance_count : 0
  secret = google_secret_manager_secret.sdm-token[count.index].id
  secret_data = lookup(data.terraform_remote_state.gcp-pipelines-sdm.outputs, "sdm-${var.deploy_name}-${var.region}")[count.index]

  lifecycle {
    ignore_changes =[
      secret_data
    ]
  }
}

# instance creation including route and firewall rule

resource "google_compute_address" "default" {
  count   = var.module_enabled && var.public ? var.instance_count : 0
  name    = "${var.deploy_name}-${var.service_name}-${var.region}-${count.index}"
  address = ""
}

data "template_file" "startup-script" {
  count   = var.module_enabled ? var.instance_count : 0
  template = file("${path.module}/files/${var.service_name}_bootstrap.sh")
  vars = {
//    gateway_token = lookup(data.terraform_remote_state.gcp-pipelines-sdm.outputs, "sdm-${var.environment}-${var.region}")[count.index]
    gateway_token = google_secret_manager_secret_version.sdm-token[count.index].secret_data
  }
}

resource "google_compute_disk" "default" {
  count = var.module_enabled && var.public ? var.instance_count : 0
  name  = "${var.deploy_name}-${var.service_name}-${var.region}-data-${count.index}"
  type  = "pd-ssd"
  zone  = var.region_zone
  size  = var.disk_size_gb
  labels = {
    environment = var.environment
  }
}

resource "google_compute_instance" "gce-pub" {
  count        = var.module_enabled && var.public ? var.instance_count : 0
  name         = "${var.deploy_name}-${var.service_name}-${var.region}-${count.index}"
  machine_type = var.machine_type
  allow_stopping_for_update = true
shielded_instance_config {
      enable_integrity_monitoring = true
      enable_vtpm                 = true
  }

  #zone         = "${element(var.var_zones, count.index)}"
  zone = var.region_zone
  tags = var.instance_tags
  boot_disk {
    initialize_params {
      image = var.compute_image
    }
  }
  labels = {
    environment = var.environment
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_key} ubuntu"
    block-project-ssh-keys = true
  }

  metadata_startup_script = data.template_file.startup-script[count.index].rendered
  network_interface {
    subnetwork = var.subnetwork
    access_config {
      nat_ip = element(
        concat(google_compute_address.default.*.address, [""]),
        count.index,
      )
    }
  }
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
    lifecycle {
    ignore_changes=[
      machine_type
    ]
  }
}

resource "google_compute_instance" "gce-nat" {
  count        = var.module_enabled  && !var.public ? var.instance_count : 0
  name         = "${var.deploy_name}-${var.service_name}-${var.region}-${count.index}"
  machine_type = var.machine_type
  allow_stopping_for_update = true

  #zone         = "${element(var.var_zones, count.index)}"
  zone = var.region_zone
  tags = var.instance_tags
  shielded_instance_config {
      enable_integrity_monitoring = true
      enable_vtpm                 = true
  }
  boot_disk {

    initialize_params {
      image = var.compute_image
    }
  }

  attached_disk {
    source = google_compute_disk.default[count.index].id
  }
  labels = {
    environment = var.environment
  }

  metadata = {
    #ssh-keys = "ubuntu:${var.ssh_key} ubuntu"
     ssh-keys = join("\n", [for key in var.ssh_key : "ubuntu:${key} ubuntu"])
    block-project-ssh-keys = true
  }

  metadata_startup_script = data.template_file.startup-script[count.index].rendered
  network_interface {
    subnetwork = var.subnetwork
  }
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "default" {
  count   = var.module_enabled ? 1 : 0
  name    = "${var.deploy_name}-${var.service_name}-${var.region}"
  network = var.network

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = var.protocol
    ports    = var.ports
  }

  source_ranges = var.ssh_source_ranges
  target_tags = var.target_tags
}
resource "google_compute_firewall" "sdm-relays" {
  count   = var.module_enabled && var.region == "us-east1" && var.environment == "prod" ? 1 : 0
  name    = "${var.deploy_name}-${var.service_name}-${var.region}-sdm-relays"
  network = var.network

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = var.protocol
    ports    = var.ports
  }

  source_ranges = concat(var.sshproxy_ips,lookup(data.terraform_remote_state.gcp-pipelines-usw1.outputs,"sshproxy_ip"),lookup(data.terraform_remote_state.gcp-pipelines-usc1.outputs,"sshproxy_ip"), lookup(data.terraform_remote_state.gcp-pipelines-euw2.outputs,"sshproxy_ip"),lookup(data.terraform_remote_state.gcp-pipelines-ape2.outputs,"sshproxy_ip"),lookup(data.terraform_remote_state.gcp-pipelines-stg-use1.outputs,"sshproxy_ip"))
  target_tags = var.target_tags
}

resource "google_compute_firewall" "sdm-relays-fw" {
  count   = var.module_enabled ? 1 : 0 
  name    = "${var.deploy_name}-${var.service_name}-${var.region}-sdm-relays-fw"
  network = var.network

  allow {
    protocol = var.protocol
    ports    = var.sdm_port
  }

  source_ranges = var.sdm_source_ranges_ips
  target_tags = var.target_tags
}