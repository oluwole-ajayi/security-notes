variable "bucket_name" {
  description = "Globally unique S3 bucket name using lowercase letters, digits and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters and contain only lowercase letters, digits and hyphens."
  }
}

variable "tags" {
  description = "Tags to apply to the bucket."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket. Keep false for production."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN. When null, the module explicitly configures SSE-S3."
  type        = string
  default     = null
}

variable "access_log_bucket" {
  description = "Optional pre-existing destination bucket for S3 server access logs."
  type        = string
  default     = null
}
