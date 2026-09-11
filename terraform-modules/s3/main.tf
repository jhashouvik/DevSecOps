/*
Wezva Technologies - Cloud Infrastructure Automation Framework
Component: S3 Storage Module
Author: Adam, Head of Platform
Optimized: For_each object looping, strict multi-tier backup archiving timelines.
*/

locals {
  aws_region = "ap-south-1"
}

provider "aws" {
  region = local.aws_region
}

data "aws_caller_identity" "current" {}

# Invoke your modular compliance bucket creation tier cleanly
module "infrastructure_compliance_storage" {
  source      = "./s3_compliance_bucket"
  environment = "production"

  # 🎯 DYNAMIC INPUT: Simply add or append bucket name strings to this variable array block
  bucket_names = [
    "wezvatech-dvc-data-lake-${data.aws_caller_identity.current.account_id}-${local.aws_region}",
    "wezvatech-rawdata-applog-${data.aws_caller_identity.current.account_id}-${local.aws_region}"
  ]
}

# Output tracking loop maps straight to your terminal screen for verification
output "deployed_infrastructure_storage_arns" {
  value = module.infrastructure_compliance_storage.bucket_arns
}


