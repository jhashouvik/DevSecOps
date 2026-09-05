
# Set AWS provider region
provider "aws" {
  region = var.aws_region
}

# Creates an encryption security policy
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name        = "example-encryption-policy"
  type        = "encryption"
  description = "encryption policy for ${var.collection_name}"
  policy = jsonencode({
    Rules = [
      {
        Resource = ["collection/${var.collection_name}"],
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

# Creates a collection
resource "aws_opensearchserverless_collection" "collection" {
  name = var.collection_name

  depends_on = [
                aws_opensearchserverless_security_policy.encryption_policy,
                aws_opensearchserverless_security_policy.network_policy,
                aws_opensearchserverless_access_policy.data_access_policy
  ]
}

# Creates a network security policy
resource "aws_opensearchserverless_security_policy" "network_policy" {
  name        = "example-network-policy"
  type        = "network"
  policy = jsonencode([
    {
      Description = "Public access to collection and Dashboards endpoint for example collection",
      Rules = [
        {
          ResourceType = "collection",
          Resource = ["collection/${var.collection_name}"]
        },
        {
          ResourceType = "dashboard",
          Resource = ["collection/${var.collection_name}"]
        }
      ],
      AllowFromPublic = true
    }
  ])
}

# Creates a VPC endpoint
resource "aws_opensearchserverless_vpc_endpoint" "vpc_endpoint" {
  name               = "example-vpc-endpoint"
  vpc_id             = var.vpcid
  subnet_ids         = var.subnetids
  security_group_ids = var.security_groups
}

# Gets access to the effective Account ID in which Terraform is authorized
data "aws_caller_identity" "current" {}

# Creates a data access policy
resource "aws_opensearchserverless_access_policy" "data_access_policy" {
  name        = "example-data-access-policy"
  type        = "data"
  description = "allow index and collection access"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index",
          Resource = ["index/${var.collection_name}/*"],
          Permission = ["aoss:*"]
        },
        {
          ResourceType = "collection",
          Resource = ["collection/${var.collection_name}"],
          Permission = ["aoss:*"]
        }
      ],
      Principal = [data.aws_caller_identity.current.arn]
    }
  ])
}

# Lifecycle policy to delete older data
resource "aws_opensearchserverless_lifecycle_policy" "example" {
  name        = "example-lifecycle-policy"
  type        = "retention"
  description = "Example retention policy for OpenSearch Serverless"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "index",
        Resource = ["index/${var.collection_name}/*"],
        MinIndexRetention = "30d"
      }
    ]
  })
}

