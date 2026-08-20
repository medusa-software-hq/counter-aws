# A regional custom domain (api.<subdomain>.<domain>) in front of the HTTP API, so clients — the CLI
# in particular — reach the API at a stable, AWS-agnostic host rather than the generated execute-api
# URL. The certificate is regional (same region as the API), unlike the CloudFront cert in us-east-1;
# it is DNS-validated through Cloudflare, the same mechanism the web foundation uses.
resource "aws_acm_certificate" "api" {
  domain_name       = module.common.api_host_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_dns_record" "api_cert_validation" {
  for_each = {
    for opt in aws_acm_certificate.api.domain_validation_options : opt.domain_name => opt
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  type    = each.value.resource_record_type
  content = trimsuffix(each.value.resource_record_value, ".")
  ttl     = 1 # "automatic"
  # API Gateway terminates TLS with its own ACM certificate, so Cloudflare must stay out of the path.
  proxied = false
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in cloudflare_dns_record.api_cert_validation : r.name]
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = module.common.api_host_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Map the custom domain to the HTTP API's $default stage, so https://<api_host>/counter/* reaches the
# same routes as the execute-api endpoint.
resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.default.id
}

# The API's public host.
resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = module.common.api_subdomain_name
  content = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
  ttl     = 1 # "automatic"
  proxied = false
}
