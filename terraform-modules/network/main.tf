#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

provider "aws" {
  region = "ap-south-1"
}

locals {
  vpc_setup = {
    "edge" = {
      cidr            = "10.10.0.0/16"
      public_subnets  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
      private_subnets = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"] # API Gateway
      nat             = false
      endpoints       = { s3 = { service = "s3", type = "Gateway" } }
    }
    "app" = {
      cidr            = "10.20.0.0/16"
      public_subnets  = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"] # ALB
      private_subnets = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24", # Control Plane
                         "10.20.21.0/24", "10.20.22.0/24", "10.20.23.0/24"] # Data Plane
      nat             = true # Routes to connect with payment gateways
      endpoints       = { ecr_api = { service = "ecr.api", type = "Interface" }, 
                          s3      = { service = "s3",      type = "Gateway"   }  # Required for Ledger service
                        }
    }
    "data" = {
      cidr            = "10.30.0.0/16"
      public_subnets  = []
      private_subnets = ["10.30.11.0/24", "10.30.12.0/24", "10.30.13.0/24", # DBs
                         "10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"] # Kafka/OS
      nat             = false
      endpoints       = { kms = { service = "kms", type = "Interface" } } # Critical for DB encryption
    }
    "ops" = {
      cidr            = "10.40.0.0/16"
      public_subnets  = ["10.40.1.0/24", "10.40.2.0/24", "10.40.3.0/24"] # NAT for external alerts
      private_subnets = ["10.40.11.0/24", "10.40.12.0/24", "10.40.13.0/24"] # Monitoring/Vault
      nat             = true
      endpoints       = { }
    }
  }
}

locals {
  tgw_needed = var.enable_tgw && length(local.vpc_setup) > 1
}

# 1. Conditional Transit Gateway
resource "aws_ec2_transit_gateway" "fintech_tgw" {
  count       = local.tgw_needed ? 1 : 0
  description = "Central Hub for Fintech VPCs"
  
  tags = { Name = "fintech-main-tgw" }
}

# 2. Conditional VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach" {
  for_each = local.tgw_needed ? module.fintech_vpcs : {}

  # Pick one subnet per AZ (slice first 3) to satisfy AWS limits
  subnet_ids         = slice(each.value.private_subnet_ids, 0, 3)
  transit_gateway_id = aws_ec2_transit_gateway.fintech_tgw[0].id
  vpc_id             = each.value.vpc_id

  tags = { Name = "tgw-attachment-${each.key}" }
}

# 3. Conditional Routes for Inter-VPC Traffic
resource "aws_route" "to_tgw" {
  # Use the original map keys so Terraform knows them upfront
  for_each = local.tgw_needed ? local.vpc_setup : {}

  route_table_id         = module.fintech_vpcs[each.key].private_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.fintech_tgw[0].id

  # Ensure the TGW and Module outputs exist before creating routes
  depends_on = [
    aws_ec2_transit_gateway.fintech_tgw,
    module.fintech_vpcs
  ]
}


module "fintech_vpcs" {
  for_each = local.vpc_setup
  source   = "./network"

  vpc_name           = each.key 
  vpc_cidr           = each.value.cidr
  public_subnets     = each.value.public_subnets
  private_subnets    = each.value.private_subnets
  enable_nat_gateway = each.value.nat
  vpc_endpoints      = each.value.endpoints

  # Security Group logic - Restricted for Fintech
  sg_public_ingress = each.key == "app" ? [{ description = "HTTP", port = 80, protocol = "tcp" }] : []
  sg_private_ingress = [443, 2049] # HTTPS and EFS/Internal comms
}

#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#
