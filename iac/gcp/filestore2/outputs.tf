output "filestore_id" {
  value = element(concat(google_filestore_instance.instance_ent.*.id, [""]), 0)
}

//output "filestore_ip" {
//  value = google_filestore_instance.instance_ent[0].networks[0].ip_addresses[0]
//}

