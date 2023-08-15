# The following outputs mysql.
output "instance_name" {
  description = "The name of the database instance"
  value = element(
    concat(google_sql_database_instance.gcp_postgres.*.name, [""]),
    0,
  )
}

output "instance_address" {
  description = "The ip of the database instance"
  value = element(
    concat(
      google_sql_database_instance.gcp_postgres.*.first_ip_address,
      [""],
    ),
    0,
  )
}

output "self_link" {
  description = "Self link to the master instance"
  value = element(
    concat(
      google_sql_database_instance.gcp_postgres.*.self_link,
      [""],
    ),
    0,
  )
}

output "postgres_admin_password" {
  value = element(concat(google_sql_user.pg_root_user.*.password, [""]), 0)
  sensitive = true
}

output "postgres_admin_username" {
  value = google_sql_user.pg_root_user.*.name
}

output "DBs" {
  value = google_sql_database_instance.gcp_postgres.*
}