
resource "aws_ecr_repository" "repo" {
  for_each             = var.repository_names
  name                 = each.value
  image_tag_mutability = var.image_mutability

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Output the repository URLs so your CI/CD pipeline can use them
output "repository_urls" {
  value       = { for k, v in aws_ecr_repository.repo : k => v.repository_url }
  description = "Map of repository names to their respective ECR URLs"
}

