terraform {
  required_version = ">= 1.8.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "hardened_s3" {
  source = "../.."

  bucket_name   = var.bucket_name
  force_destroy = true

  tags = {
    Environment = "lab"
    Project     = "cloud-security-lab-04"
    ManagedBy   = "terraform"
  }
}

variable "aws_region" {
  description = "AWS region for the lab deployment."
  type        = string
  default     = "eu-west-2"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

output "bucket_name" {
  value = module.hardened_s3.bucket_id
}
