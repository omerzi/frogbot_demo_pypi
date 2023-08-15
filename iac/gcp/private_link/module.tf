
resource "google_compute_forwarding_rule" "pl_forwarding_rule" {
  count              = var.module_enabled ? 1 : 0
  name   = "${var.deploy_name}-${var.region}-pl-forwarding-rule"
  region = var.region

  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.gcp-pe-lb[0].id
  ports                 = var.ports
  network               = var.network
  subnetwork            = var.lb_subnet
}

resource "google_compute_region_backend_service" "gcp-pe-lb" {
  count = var.module_enabled ? 1 : 0
  name = "${var.deploy_name}-${var.region}-pl-lb"
  health_checks = [google_compute_health_check.pl_hc[0].id]
  network = var.network
  connection_draining_timeout_sec = 300
   dynamic "backend" {
    for_each = var.pl_node_pool != "" ? var.pl_node_pool  : []
    content {
      group =   backend.value 
    }
  }
}

resource "google_compute_health_check" "pl_hc" {
  count              = var.module_enabled ? 1 : 0
  name   = "${var.deploy_name}-${var.region}-pl-hc"
  check_interval_sec = var.pl_hc.check_interval_sec
  healthy_threshold  = var.pl_hc.healthy_threshold
  unhealthy_threshold = var.pl_hc.unhealthy_threshold
  timeout_sec        = var.pl_hc.timeout_sec
  project            = var.project_name
  log_config {
    enable = var.log_config
  }
  tcp_health_check{
    port = 443
    proxy_header = "PROXY_V1"
  }
}
  
resource "google_compute_firewall" "pl_fw_rule" {
  count = var.module_enabled ? 1 : 0
  name = "${var.deploy_name}-${var.region}-pl-healthcheck"
  network = var.network
  project = var.project_name

  allow {
    protocol  = "tcp"
    ports     = ["443"]
  }
  target_tags = ["k8s-private"]
  source_ranges = ["35.191.0.0/16","130.211.0.0/22"] //gcp healthcheck source ips https://cloud.google.com/load-balancing/docs/health-checks
}



resource "google_compute_service_attachment" "pl_service_attachment" {
  count       = var.module_enabled ? 1 : 0
  name   = "${var.deploy_name}-${var.region}-pl-service-attachment"
  region      = var.region
  description = "A service attachment configured with Terraform for private link"

  enable_proxy_protocol    = true
  connection_preference    = "ACCEPT_MANUAL"
  nat_subnets              = [var.pl_subnet]
  target_service           = google_compute_forwarding_rule.pl_forwarding_rule[0].id
  lifecycle {
    ignore_changes=[
     consumer_accept_lists   
    ]
  }
  depends_on = [
    google_compute_forwarding_rule.pl_forwarding_rule[0]
  ]
}
