#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

#--------------
# Create a VPC
#--------------

resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(
    {
       Name        = "fintech-${var.vpc_name}-vpc"
       Environment = "production"
       Org         = "wezvatech" # Keep the org name here
  }
  )
}

#-------------------------------
# Create an IGW for your new VPC
#-------------------------------
resource "aws_internet_gateway" "my_igw" {
  count = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.my_vpc.id

  tags = merge(
    { "Name" = var.name
      "project" = var.igw_tags
	}
  )
}

# --------------------------------------------------------
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION
# --------------------------------------------------------
data "aws_availability_zones" "all" {}

#-----------------------
# Create a Public subnet 
#-----------------------
resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnets)
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = element(var.public_subnets, count.index)
  availability_zone = data.aws_availability_zones.all.names[count.index]

  tags = merge(
    { 
      Name = "fintech-${var.vpc_name}-public-subnet-${count.index}"
      "project" = var.public_subnet_tags
    }
  )
  
}

#----------------------------------
# Create an RouteTable for your VPC
#----------------------------------
resource "aws_route_table" "public" {
    count = length(var.public_subnets) > 0 ? 1 : 0
    vpc_id = aws_vpc.my_vpc.id

    tags = {
        Name = "DEMO Public RouteTable - WEZVATECH"
    }
}

#----------------------------------------
# Associate the RouteTable to the Subnets 
#----------------------------------------
resource "aws_route_table_association" "public" {
    count = length(var.public_subnets)
    subnet_id = element(aws_subnet.public_subnet.*.id, count.index)
    route_table_id = aws_route_table.public[0].id
}

#----------------------------------
# Add route entry to the RouteTable
#----------------------------------
resource "aws_route" "public_internet_gateway" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw[0].id

  timeouts {
    create = "5m"
  }
}

#--------------------------
# CREATE THE SECURITY GROUP 
#--------------------------
resource "aws_security_group" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.my_vpc.id


  # Allow all outbound 
   dynamic "egress" {
        for_each = var.sg_public_egress
        content {
            from_port   = egress.value
            to_port     = egress.value
            protocol    = "tcp"
            cidr_blocks = [ "0.0.0.0/0" ]
        }
    }

  # Inbound for SSH
   dynamic "ingress" {
    for_each = var.sg_public_ingress
    content {
      cidr_blocks = [ "0.0.0.0/0" ]
      description      = ingress.value["description"]
      from_port        = ingress.value["port"]
      to_port          = ingress.value["port"]
      protocol         = ingress.value["protocol"]
    }
  }
  
}

#----------------------------------
# Create a Private subnet
#----------------------------------
resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnets)
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = element(var.private_subnets, count.index)
  availability_zone = data.aws_availability_zones.all.names[count.index % length(data.aws_availability_zones.all.names)]

  tags = merge(
    { 
      Name = "fintech-${var.vpc_name}-private-subnet-${count.index}"
      "project" = var.private_subnet_tags
    }
  )
}

#----------------------------------
# Create an RouteTable for Private subnet
#----------------------------------
resource "aws_route_table" "private" {
    count = length(var.private_subnets) > 0 ? 1 : 0
    vpc_id = aws_vpc.my_vpc.id

    tags = {
        Name = "DEMO private RouteTable - WEZVATECH"
    }
}

#----------------------------------------
# Associate the RouteTable to Private Subnets
#----------------------------------------
resource "aws_route_table_association" "private" {
    count = length(var.private_subnets)
    subnet_id = element(aws_subnet.private_subnet.*.id, count.index)
    route_table_id = aws_route_table.private[0].id
}

#--------------------------
# CREATE THE SECURITY GROUP FOR PRIVATE
#--------------------------
resource "aws_security_group" "private" {
  count = length(var.private_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.my_vpc.id


  # Allow all outbound
   dynamic "egress" {
        for_each = var.sg_private_egress
        content {
            from_port   = egress.value
            to_port     = egress.value
            protocol    = "tcp"
            cidr_blocks = [ "0.0.0.0/0" ]
        }
    }
}

#--------------------------
# CREATE THE INGRESS RULES
#--------------------------
resource "aws_security_group_rule" "private" {
   count = length(var.sg_private_ingress) > 0 ? 1 : 0
   type              = "ingress"
   from_port         = var.sg_private_ingress[count.index]
   to_port           = var.sg_private_ingress[count.index]
   protocol          = "tcp"
   security_group_id = aws_security_group.private[0].id
   cidr_blocks = [ "0.0.0.0/0" ]
}


locals {
  nat_gateway_ips   = var.reuse_nat_ips ? var.external_nat_ip_ids : try(aws_eip.nat[*].id, [])
}

#--------------------------
# CREATE EIP FOR NAT GATEWAY
#--------------------------
resource "aws_eip" "nat" {
  count =  var.enable_nat_gateway && length(var.public_subnets) > 0 ? 1 : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.my_igw]
}

#-------------------
# CREATE NAT GATEWAY
#-------------------
resource "aws_nat_gateway" "public" {
  count =  var.enable_nat_gateway && length(var.public_subnets) > 0 ? 1 : 0
  allocation_id = element(local.nat_gateway_ips, count.index)
  subnet_id = aws_subnet.public_subnet[0].id

  depends_on = [aws_internet_gateway.my_igw]
}

#-------------------------
# MAP ROUTE FOR NAT GATEWAY
#--------------------------
resource "aws_route" "private_nat_gateway" {
  count =  var.enable_nat_gateway && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id              = aws_route_table.private[0].id
  destination_cidr_block = var.nat_gateway_destination_cidr_block
  nat_gateway_id              = aws_nat_gateway.public[0].id

  timeouts {
    create = "5m"
  }
}

#-------------------------------------------
# VPC ENDPOINTS (DYNAMICALY CREATED)
#-------------------------------------------

# Security group for Interface endpoints (Port 443)
resource "aws_security_group" "endpoint_sg" {
  count       = length([for e in var.vpc_endpoints : e if e.type == "Interface"]) > 0 ? 1 : 0
  name        = "${var.name}-endpoint-sg"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_vpc_endpoint" "demo" {
  for_each          = var.vpc_endpoints
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.ap-south-1.${each.value.service}"
  vpc_endpoint_type = each.value.type

  # Interface-specific logic
  security_group_ids  = each.value.type == "Interface" ? [aws_security_group.endpoint_sg[0].id] : null
  subnet_ids = each.value.type == "Interface" ? slice(
    aws_subnet.private_subnet[*].id, 
    0, 
    length(data.aws_availability_zones.all.names)
  ) : null
  #subnet_ids          = each.value.type == "Interface" ? aws_subnet.private_subnet[*].id : null
  private_dns_enabled = each.value.type == "Interface" ? each.value.private_dns : null

  # Gateway-specific logic (S3/DynamoDB)
  route_table_ids = each.value.type == "Gateway" ? [aws_route_table.private[0].id] : null

  tags = {
    Name = "${var.name}-${each.key}-endpoint"
  }
}


#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#
