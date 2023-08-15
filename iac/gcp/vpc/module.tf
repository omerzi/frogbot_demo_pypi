# Creation of Network, subnets and IP ranges

resource "google_compute_network" "private-network" {
  count                   = var.module_enabled ? 1 : 0
  name                    = "${var.deploy_name}-${var.region}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "public-subnet" {
  count         = var.module_enabled ? 1 : 0
  name          = "${var.deploy_name}-public-subnet"
  ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "public" )
  network       = google_compute_network.private-network[0].self_link
  region        = var.region
}

resource "google_compute_subnetwork" "private-subnet" {
  count                    = var.is_sub_region || var.module_enabled ? 1 : 0
  name                     = "${var.deploy_name}-private-subnet"
  ip_cidr_range            = lookup(var.vpc_map.subnet_cidr, "private" )
  network                  = var.is_sub_region ? var.vpc_self_link : google_compute_network.private-network[0].self_link
  region                   = var.region
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-private-range"
    ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "k8s-pods" )
  }
  secondary_ip_range {
    range_name    = "services-private-range"
    ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "k8s-services" )
  }
}

resource "google_compute_subnetwork" "data-subnet" {
  count         = var.module_enabled && contains(keys(var.vpc_map.subnet_cidr), "data")  ? 1 : 0
  name          = "${var.deploy_name}-data-subnet"
  ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "data" )
  network       = google_compute_network.private-network[0].self_link
  region        = var.region
}

resource "google_compute_subnetwork" "mgmt-subnet" {
  count         = var.module_enabled ?1 : 0
  name          = "${var.deploy_name}-mgmt-subnet"
  ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "mgmt" )
  network       = google_compute_network.private-network[0].self_link
  region        = var.region
}

resource "google_compute_subnetwork" "private_link-subnet" {
  count         = var.module_enabled &&  contains(keys(var.vpc_map.subnet_cidr), "pl") ? 1 : 0
  name          = "${var.deploy_name}-pl-subnet"
  ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "pl" )
  network       = google_compute_network.private-network[0].self_link
  region        = var.region
  purpose       = "PRIVATE_SERVICE_CONNECT"
}
resource "google_compute_subnetwork" "private_lb-subnet" {
  count         = var.module_enabled &&  contains(keys(var.vpc_map.subnet_cidr), "internal-lb") ? 1 : 0
  name          = "${var.deploy_name}-internal-lb-subnet"
  ip_cidr_range = lookup(var.vpc_map.subnet_cidr, "internal-lb" )
  network       = google_compute_network.private-network[0].self_link
  region        = var.region
}
resource "google_compute_address" "nat-address" {
  count  = var.is_sub_region ? 0 : 2
  name   = "nat-external-address-${count.index}"
  region = var.region
}

resource "google_compute_router" "router" {
  count    = var.module_enabled ? 1 : 0
  provider = google-beta
  name     = "router"
  region   = google_compute_subnetwork.public-subnet[0].region
  network  = google_compute_network.private-network[0].self_link
  bgp {
    asn = 64514
    keepalive_interval = var.bgp_keepalive_interval
  }
}

resource "google_compute_router_nat" "advanced-nat" {
  count                              = var.module_enabled ? 1 : 0
  provider                           = google-beta
  name                               = "${var.deploy_name}-nat"
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.nat-address.*.self_link
  min_ports_per_vm                   = contains(keys(var.vpc_map),"nat_gateway") == true ? lookup(var.vpc_map.nat_gateway,"min_ports_per_vm",64) : 64
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = var.enable_endpoint_independent_mapping

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "private_ip_address" {
  count    = try(length(var.private_ip_address),0)
  provider = google-beta
  name          = lookup(var.private_ip_address[count.index],"name","google-managed-services-k8s-saas-${count.index}-${var.region}")
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  description   = lookup(var.private_ip_address[count.index],"description","")
  prefix_length = var.private_ip_address[count.index]["prefix_length"]
  address       = var.private_ip_address[count.index]["address"]
  network       = google_compute_network.private-network[0].id
}
resource "google_service_networking_connection" "private_vpc_connection" {
  count    = try(length(var.private_ip_address),0) > 0  ? 1 : 0
  provider = google-beta
  network                 = google_compute_network.private-network[count.index].name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = "${google_compute_global_address.private_ip_address[*].name}"
}