# =============================================================================
# CloudFront + Route 53 + ACM Custom Domain Setup
# =============================================================================
#
# Architecture:
#   Browser -> Route 53 (ALIAS) -> CloudFront -> S3 (Origin)
#              ACM cert (us-east-1) validates the custom domain
#
# 3 requirements for CloudFront custom domains:
#   1. ACM certificate in us-east-1 (ISSUED status)
#   2. CloudFront Alternate Domain Name (aliases)
#   3. CloudFront viewer_certificate referencing the ACM cert
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

# Default provider
provider "aws" {
  region = var.aws_region
}

# CloudFront requires ACM certificates in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
