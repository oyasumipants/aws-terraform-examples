# =============================================================================
# Step 2: Add Custom Domain to CloudFront
# =============================================================================
#
# This step adds a custom domain to the CloudFront distribution from Step 1.
# After applying, you can access the site via your own domain (e.g., app.example.com).
#
# What changes from Step 1:
#   - ACM certificate created in us-east-1
#   - DNS validation records in Route 53
#   - CloudFront aliases + viewer_certificate updated
#   - Route 53 ALIAS record pointing to CloudFront
#
# Architecture:
#   Browser -> Route 53 (ALIAS) -> CloudFront -> S3 (Origin)
#              ACM cert (us-east-1) validates the custom domain
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# CloudFront requires ACM certificates in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
