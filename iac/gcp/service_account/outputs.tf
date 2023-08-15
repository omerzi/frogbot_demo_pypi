output "email" {
  value       = element(concat(google_service_account.default.*.email, [""]), 0)
  description = "The e-mail address of the service account."
}

output "name" {
  value       = element(concat(google_service_account.default.*.name, [""]), 0)
  description = "The fully-qualified name of the service account."
}

output "unique_id" {
  value       = element(concat(google_service_account.default.*.unique_id, [""]), 0)
  description = "The unique id of the service account."
}

output "private_key" {
  value = element(
    concat(google_service_account_key.default.*.private_key, [""]),
    0,
  )
}

output "decoded_private_key" {
  value = base64decode(
    element(
      concat(google_service_account_key.default.*.private_key, [""]),
      0,
    ),
  )
}

