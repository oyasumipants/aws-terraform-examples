variable "aws_region" {
  description = "AWS region for resources (except ACM which uses us-east-1)"
  type        = string
  default     = "ap-northeast-1"
}

variable "domain_name" {
  description = "Custom domain name for CloudFront (e.g., app.example.com)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for the domain"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cloudfront-custom-domain"
}
