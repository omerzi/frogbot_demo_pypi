
output "public-ip" {
  description = "The external IP address of the sshproxy instance."
//  value       = element(concat(google_compute_address.default.*.address, [""]), 0)
    value       = google_compute_address.sshproxy.*.address
}

output "ssh_proxy_sa" {
  value = google_service_account.ssh_proxy.email
}