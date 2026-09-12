variable "aws_region" {
  type        = string
  description = "Target deployment AWS region space"
  default     = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "Execution environment naming prefix context"
  default     = "production"
}

variable "raw_ingestion_bucket_id" {
  type        = string
  description = <<-EOT
    The central S3 ingestion bucket monitored for real-time dataset uploads.
    Must match the data lake bucket deployed by terraform-modules/s3 (see that
    module's `deployed_infrastructure_storage_arns` output), for example
    wezvatech-dvc-data-lake-<account_id>-ap-south-1.
    Only uploads under the "raw/" prefix trigger the gateway; the Lambda writes
    sanitized output under "processed/" in the same bucket.
  EOT
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Execution timeout window for processing heavy CSV token blocks (Max 900)"
  default     = 120
}

