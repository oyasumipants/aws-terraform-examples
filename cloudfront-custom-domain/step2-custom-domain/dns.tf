# =============================================================================
# Route 53 ALIAS Record — NEW in Step 2
# =============================================================================
# Points the custom domain to the CloudFront distribution.
# ALIAS is Route 53 specific — resolves to IP directly (unlike CNAME).
# Can be used at the zone apex (e.g., example.com).

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
