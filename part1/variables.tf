variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (update per region)"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # us-east-1 Ubuntu 22.04
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the existing EC2 key pair for SSH access"
  type        = string
  default     = "my-key-pair"   # <-- replace with your key pair name
}
