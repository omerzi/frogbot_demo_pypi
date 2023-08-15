output "filestore_id" {
  value = var.module_enabled ? element(concat(google_filestore_instance.instance.*.id, [""]), 0) : null
}

output "filestore_ip" {
  value = var.module_enabled ? google_filestore_instance.instance[0].networks[0].ip_addresses[0] : null
}

