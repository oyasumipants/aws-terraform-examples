output "cloudfront_domain_name" {
  description = "CloudFront domain — open this URL in your browser"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (used in Step 2)"
  value       = aws_cloudfront_distribution.this.id
}

output "s3_bucket_name" {
  description = "S3 origin bucket name"
  value       = aws_s3_bucket.origin.id
}
