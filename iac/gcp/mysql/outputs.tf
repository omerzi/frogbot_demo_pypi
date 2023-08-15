# The following outputs mysql.
output "instance_name" {
  description = "The name of the database instance"
  value = element(
    concat(
      google_sql_database_instance.new_instance_sql_master.*.name,
      [""],
    ),
    0,
  )
}

output "instance_address" {
  description = "The ip of the database instance"
  value = element(
    concat(
      google_sql_database_instance.new_instance_sql_master.*.first_ip_address,
      [""],
    ),
    0,
  )
}

output "self_link" {
  description = "Self link to the master instance"
  value = element(
    concat(
      google_sql_database_instance.new_instance_sql_master.*.self_link,
      [""],
    ),
    0,
  )
}

output "mysql_admin_password" {
  value = element(concat(google_sql_user.default.*.password, [""]), 0)
}

output "mysql_admin_username" {
  value = google_sql_user.default.*.name
}

