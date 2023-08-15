# The following outputs allow authentication and connectivity to the GKE Cluster.
output "client_certificate" {
  value = google_container_cluster.primary.*.master_auth.0.client_certificate
}

output "client_key" {
  value = element(
    concat(
      google_container_cluster.primary.*.master_auth.0.client_key,
      [""],
    ),
    0,
  )
}

output "cluster_ca_certificate" {
  value = element(
    concat(
      google_container_cluster.primary.*.master_auth.0.cluster_ca_certificate,
      [""],
    ),
    0,
  )
}

output "cluster_name" {
  value = element(concat(google_container_cluster.primary.*.name, [""]), 0)
}

output "cluster_ip" {
  value = element(concat(google_container_cluster.primary.*.endpoint, [""]), 0)
}
output "worker_id" {
  value =element(google_container_node_pool.worker[0].managed_instance_group_urls ,0)
}

output "npx" {
  value = tomap({ 
        for k,v in google_container_node_pool.nginxplus : k => v.managed_instance_group_urls
   })
}
# output "cluster_username" {
#   value = element(
#     concat(
#       google_container_cluster.primary.*.master_auth.0.username,
#       [""],
#     ),
#     0,
#   )
# }

# output "cluster_password" {
#   value = element(
#     concat(
#       google_container_cluster.primary.*.master_auth.0.password,
#       [""],
#     ),
#     0,
#   )
#   sensitive = true
# }

