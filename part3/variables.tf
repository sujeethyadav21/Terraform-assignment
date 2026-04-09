variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Your AWS account ID (used for ECR push commands)"
  type        = string
  default     = "123456789012"  # <-- replace with your account ID
}
