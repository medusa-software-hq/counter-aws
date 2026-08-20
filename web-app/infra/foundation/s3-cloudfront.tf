# The SPA is a static bundle in a private S3 bucket, served through CloudFront.
# CloudFront reads the bucket via an Origin Access Control (SigV4); the bucket
# itself is closed to the public. The deploy workflow syncs the built bundle
# into the bucket and invalidates the distribution.

locals {
  # Globally-unique bucket name (S3 names are account-agnostic). Per environment
  # via the suffix; the account id keeps it unique across accounts.
  spa_bucket_name = "${module.common.aws_resource_prefix}-web${module.common.resource_name_suffix}-${module.common.aws_account_id}"

  # The API Gateway endpoint, as a bare host for a CloudFront origin (no scheme).
  api_origin_host = replace(trimsuffix(data.terraform_remote_state.api.outputs.api_endpoint, "/"), "https://", "")
}

data "terraform_remote_state" "api" {
  backend = "s3"

  # Read the API foundation state for THIS environment: the web + API foundations use matching
  # workspaces (prod, staging), so staging web points at the staging API,
  # not production's.
  workspace = terraform.workspace

  config = {
    bucket = "ms-tfstate-aws-682544514886"
    key    = "projects/counter/aws/backend/foundation/terraform.tfstate"
    region = "eu-central-1"
  }
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

# The SPA calls same-origin "/api/...", but the API's operation paths are mounted at the
# root — strip the "/api" prefix before the request reaches the API.
resource "aws_cloudfront_function" "strip_api_prefix" {
  name    = "${module.common.aws_resource_prefix}-strip-api${module.common.resource_name_suffix}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      request.uri = request.uri.replace(/^\/api/, '');
      if (request.uri === '') {
        request.uri = '/';
      }
      return request;
    }
  JS
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

  # The API Gateway HTTP API endpoint. A Cognito JWT authorizer is the gate, so there is no Origin
  # Access Control — the viewer's Authorization header is forwarded for it by the origin request
  # policy below.
  origin {
    origin_id   = "api-func-url"
    domain_name = local.api_origin_host

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
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

  # The API: pass every method through to the Lambda, uncached. The counter's writes are
  # POSTs that must not be cached.
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "api-func-url"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false
    # AWS-managed "CachingDisabled".
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AWS-managed "AllViewerExceptHostHeader": forward everything (incl. the future
    # Authorization header) but let CloudFront set the Host so SigV4 signing matches
    # the API.
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.strip_api_prefix.arn
    }
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
