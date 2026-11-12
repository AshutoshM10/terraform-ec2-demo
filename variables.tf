variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance size (t3.micro is free-tier eligible in most regions)"
  type        = string
  default     = "t3.micro"
}

variable "name" {
  description = "Value of the Name tag on the instance"
  type        = string
  default     = "terraform-ec2-demo"
}
