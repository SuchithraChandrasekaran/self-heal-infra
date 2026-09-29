variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "admin_email" {
  description = "Email address to receive budget alert notifications"
  type        = string
  # No default on purpose — set this in terraform.tfvars (not committed) before applying
}
