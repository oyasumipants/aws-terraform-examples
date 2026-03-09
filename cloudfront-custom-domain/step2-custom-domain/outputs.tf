output "cloudfront_domain_name" {
  description = "CloudFront domain (still accessible)"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL — open this in your browser"
  value       = "https://${var.domain_name}"
}

output "certificate_arn" {
  description = "ACM certificate ARN (us-east-1)"
  value       = aws_acm_certificate.this.arn
}
