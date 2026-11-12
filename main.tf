terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state so local runs and CI share one record of what exists.
  # bucket and region are passed at init: terraform init -backend-config="bucket=..." -backend-config="region=..."
  backend "s3" {
    key          = "terraform-ec2-demo/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # native S3 locking, no DynamoDB table needed
  }
}

# Credentials come from the environment (AWS_PROFILE, env vars, or SSO), never from this file.
provider "aws" {
  region = var.region
}

# Latest Amazon Linux 2023 AMI for the chosen region, so no AMI ID is hardcoded.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "demo" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  # Require IMDSv2 (blocks the older, SSRF-prone metadata API).
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = var.name
  }
}
