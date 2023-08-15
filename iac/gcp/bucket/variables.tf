variable "module_enabled" {
  default = true
}

variable "deploy_name" {
}

variable "name" {
  type        = list(string)
  default     = ["test1_bucket", "test2-bucket", "test3_bucket"]
  description = "The name of the bucket."
}

variable "location" {
  description = "The GCS location."
  default     = "US"
}

variable "project_name" {
  description = "The project in which the resource belongs. If it is not provided, the provider project is used."
  default     = ""
}

variable "force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects."
  default     = "false"
}

variable "storage_class" {
  description = "The Storage Class of the new bucket. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE."
  default     = "MULTI_REGIONAL"
}

# lifecycle_rule condition block
variable "age" {
  description = "Minimum age of an object in days to satisfy this condition."
  default     = "60"
}

variable "created_before" {
  description = "Creation date of an object in RFC 3339 (e.g. 2017-06-13) to satisfy this condition."
  default     = "2017-06-13"
}

variable "with_state" {
  type        = string
  default     = "ANY"
  description = "Match to live and/or archived objects. Unversioned buckets have only live objects. Supported values include: LIVE, ARCHIVED, ANY."
}

variable "matches_storage_class" {
  description = "Storage Class of objects to satisfy this condition. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, STANDARD, DURABLE_REDUCED_AVAILABILITY."
  type        = list(string)
  default     = ["MULTI_REGIONAL"]
}

variable "num_newer_versions" {
  description = "Relevant only for versioned objects. The number of newer versions of an object to satisfy this condition."
  default     = "10"
}

# lifecycle_rule action block
variable "action_type" {
  description = "The type of the action of this Lifecycle Rule. Supported values include: Delete and SetStorageClass."
  default     = "SetStorageClass"
}

variable "action_storage_class" {
  description = "The target Storage Class of objects affected by this Lifecycle Rule. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE."
  default     = "NEARLINE"
}

# versioning block
variable "versioning_enabled" {
  description = "While set to true, versioning is fully enabled for this bucket."
  default     = "true"
}

# bucket ACL

variable "default_acl" {
  description = "Configure this ACL to be the default ACL."
  default     = "private"
}

variable "role_entity" {
  description = "List of role/entity pairs in the form ROLE:entity."
  type        = list(string)
  default     = []
}

