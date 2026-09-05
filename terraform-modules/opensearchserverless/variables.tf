
variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "ap-south-1"
}

variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection."
  default     = "wezvatech-collection"
}

variable "vpcid" {
  description = "VPC in which opensearch should be created"
  default = "vpc-0574a0a509838cd31"
}

variable "subnetids" {
  description = "subnet ids"
  type        = list(string)
  default = ["subnet-08e8146d5754843f7","subnet-0085f77c1a13eb36c","subnet-0ad5ec3834e796e0d"]
}


variable "security_groups" {
  description = "A list of security group IDs to associate"
  type        = list(string)
  default = ["sg-0a7e1529fed5652fe"]
}

