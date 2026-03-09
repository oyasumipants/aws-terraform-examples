# =============================================================================
# Route 53 ALIAS Record — Custom Domain: Requirement 1
# =============================================================================
# ALIAS record points the custom domain to CloudFront.
# Unlike CNAME, ALIAS resolves to IP addresses directly and can be used
# at the zone apex (e.g., example.com).

resource "aws_route53_record" "cloudfront_alias" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
