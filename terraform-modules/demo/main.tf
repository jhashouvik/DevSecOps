# ------------------------------------------------------------------- #
# Use this project to provision Test EC2 servers
# Map variable defines the details of each server you are provisioning
#    Name/Tag of the server = Type of the server
# AUTHOR: ADAM M | +91-9739110917 
# ------------------------------------------------------------------- #

provider "aws" {
  region = "ap-south-1"
}

variable "myhosts" {
  type = map
  default = {
    TESTMACHINE = "t2.large"
  }
}

variable "amiid" {
  default = "ami-01a00762f46d584a1"
}

variable "mykey" { 
  default = "wezva2026"
}

module "server" {
  for_each = var.myhosts
  servername = each.key
  type = each.value  
  pemfile = var.mykey
  amiid = var.amiid
  source = "../instances"
}

