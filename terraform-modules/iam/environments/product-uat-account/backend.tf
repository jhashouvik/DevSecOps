terraform {
  backend "s3" {
    bucket         = "wezvatech-2026-tfstate"
    key            = "product-name/envs/uat_iam.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    
    # Enable new native locking
    use_lockfile   = true 

  }
}
