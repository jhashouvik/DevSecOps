terraform {
  backend "s3" {
    bucket       = "wezvatech-interview-prep-bucket" # Change to your real bucket
    key          = "troubleshoot-lab/security-group.tfstate"
    region       = "ap-south-1"
    use_lockfile = true # Enables native S3 state locking
  }
}

