# The SPA is a static bundle in a private S3 bucket, served through CloudFront.
# CloudFront reads the bucket via an Origin Access Control (SigV4); the bucket
# itself is closed to the public. The deploy workflow syncs the built bundle
# into the bucket and invalidates the distribution.

locals {
  # Globally-unique bucket name (S3 names are account-agnostic). Per environment
  # via the suffix; the account id keeps it unique across accounts.
  spa_bucket_name = "${module.common.aws_resource_prefix}-web${module.common.resource_name_suffix}-${module.common.aws_account_id}"
}

resource "aws_s3_bucket" "spa" {
  bucket = local.spa_bucket_name
}

resource "aws_s3_bucket_public_access_block" "spa" {
  bucket = aws_s3_bucket.spa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "spa" {
  bucket = aws_s3_bucket.spa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.spa.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.spa.arn }
      }
    }]
  })
}

resource "aws_cloudfront_origin_access_control" "spa" {
  name                              = "${module.common.aws_resource_prefix}-web${module.common.resource_name_suffix}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "spa" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [module.common.web_host_name]
  # NA + EU only — cheapest tier that covers where this app is used.
  price_class = "PriceClass_100"

  origin {
    origin_id                = "spa-s3"
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.spa.id
  }

  default_cache_behavior {
    target_origin_id       = "spa-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    # AWS-managed "CachingOptimized" policy.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # Client-side routing: unknown paths are SPA routes, not real objects, so serve
  # index.html rather than S3's 403/404.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.spa.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# TLS certificate for the web host. Must live in us-east-1 for CloudFront.
resource "aws_acm_certificate" "spa" {
  provider = aws.us_east_1

  domain_name       = module.common.web_host_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM's DNS-validation records, published in Cloudflare.
resource "cloudflare_dns_record" "cert_validation" {
  for_each = {
    for opt in aws_acm_certificate.spa.domain_validation_options : opt.domain_name => opt
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  type    = each.value.resource_record_type
  content = trimsuffix(each.value.resource_record_value, ".")
  ttl     = 1 # "automatic"
  proxied = false
}

resource "aws_acm_certificate_validation" "spa" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.spa.arn
  validation_record_fqdns = [for r in cloudflare_dns_record.cert_validation : r.name]
}

output "spa_bucket_name" {
  value = aws_s3_bucket.spa.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.spa.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.spa.domain_name
}
