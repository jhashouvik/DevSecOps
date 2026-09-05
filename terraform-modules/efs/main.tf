
#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

provider "aws" {
  region = "ap-south-1"
}

variable "default_vpc_id" {
 default = "vpc-0574a0a509838cd31"
}

variable "default_subnet_id" {
 default = ["subnet-08e8146d5754843f7", "subnet-0085f77c1a13eb36c", "subnet-0ad5ec3834e796e0d"]
}

resource "aws_efs_file_system" "wezvatech" {
  creation_token = "jrp"
  encrypted = true

  tags = {
    Name = "jrp"
  }
}

resource "aws_efs_mount_target" "example" {
 for_each = toset(var.default_subnet_id)
 file_system_id = aws_efs_file_system.wezvatech.id
 subnet_id = each.key
}

#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#
