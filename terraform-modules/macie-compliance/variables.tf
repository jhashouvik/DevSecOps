variable "aws_region" {
  type        = string
  description = "Target deployment AWS region"
  default     = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "Execution environment prefix context"
  default     = "production"
}

variable "security_team_email" {
  type        = string
  description = "The destination email address to receive immediate PII leak alerts. The SNS subscription requires manual confirmation via the email AWS sends on first apply."
}

