output "vpc-private-network" {
  value = element(
    concat(google_compute_network.private-network.*.self_link, [""]),
    0,
  )
}

output "vpc-public-subnet" {
  value = element(
    concat(google_compute_subnetwork.public-subnet.*.self_link, [""]),
    0,
  )
}

output "vpc-private-subnet" {
  value = element(
    concat(google_compute_subnetwork.private-subnet.*.self_link, [""]),
    0,
  )
}

output "vpc-internal-lb-subnet" {
  value = element(
    concat(google_compute_subnetwork.private_lb-subnet.*.self_link, [""]),
    0,
  )
}
output "vpc-data-subnet" {
  value = element(
    concat(google_compute_subnetwork.data-subnet.*.self_link, [""]),
    0,
  )
}

output "vpc-pl-subnet" {
  value = contains(keys(var.vpc_map.subnet_cidr), "pl") ? element(
    concat(google_compute_subnetwork.private_link-subnet.*.self_link, [""]),
    0,
  ) : null
} 
output "vpc-mgmt-subnet" {
  value = element(
    concat(google_compute_subnetwork.mgmt-subnet.*.self_link, [""]),
    0,
  )
}

output "natgw-ip" {
  value = google_compute_address.nat-address.*.address
}

output "vpc-private-network-id" {
  value = try(element(
  concat(google_compute_network.private-network.*.name, [""]),
  0,
  ))
}