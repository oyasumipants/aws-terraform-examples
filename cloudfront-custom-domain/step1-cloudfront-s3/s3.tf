# =============================================================================
# S3 Origin Bucket
# =============================================================================

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "origin" {
  bucket = "${var.project_name}-origin-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-origin"
  }
}

# Upload a sample index.html to verify the setup
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.origin.id
  key          = "index.html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html>
    <head><title>CloudFront Handson</title></head>
    <body>
      <h1>Hello from CloudFront!</h1>
      <p>If you see this page, CloudFront + S3 is working correctly.</p>
    </body>
    </html>
  HTML
  content_type = "text/html"
}
