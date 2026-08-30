variable "env_type" { type = string } # "dev", "qa", "uat", or "prod"

variable "region" {
  default = "ap-south-1"
}

variable "account_id" {}
variable "enable_platform_role" { default = false }
variable "enable_product_role"  { default = false }
variable "enable_cicd_role"     { default = false }

