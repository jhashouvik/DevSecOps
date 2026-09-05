variable "repository_names" {
  type        = set(string)
  description = "List of repository names to create"
}

variable "image_mutability" {
  type        = string
  default     = "MUTABLE"
  description = "The tag mutability setting for the repository"
}

