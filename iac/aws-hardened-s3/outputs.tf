output "bucket_id" {
  description = "Name of the deployed bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the deployed bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the deployed bucket."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
