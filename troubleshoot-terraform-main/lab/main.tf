provider "aws" {
  region = "ap-south-1"
}
# Add this provider block
terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

resource "aws_security_group" "sg_1" {
  name        = "wezva-prod-web-sg"
  description = "Production Web Security Group"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ⏳ THE SPEED BUMP: This holds the S3 remote lock open for 15 seconds
resource "time_sleep" "wait_between_resources" {
  depends_on      = [aws_security_group.sg_1]
  create_duration = "15s"
}

resource "aws_security_group" "sg_2" {
  name        = "wezva-prod-db-sg"
  description = "Production Database Security Group"
  
  # This forces sg_2 to wait for the sleep timer to finish
  depends_on  = [time_sleep.wait_between_resources]

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}
