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

resource "aws_s3_bucket" "comparison_only" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Environment = "lab"
    Purpose     = "plan-only-relaxed-guardrails-comparison"
  }
}

resource "aws_s3_bucket_public_access_block" "comparison_only" {
  bucket = aws_s3_bucket.comparison_only.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "bucket_name" {
  description = "Globally unique lab bucket name."
  type        = string
}
