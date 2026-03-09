# =============================================================================
# Step 1: CloudFront + S3 (No Custom Domain)
# =============================================================================
#
# This step creates a basic CloudFront distribution with an S3 origin.
# You can access the site via the CloudFront domain (e.g., d1234.cloudfront.net).
#
# Architecture:
#   Browser -> CloudFront (d1234.cloudfront.net) -> S3 (Origin)
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
