# The SPA's public host.
resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = module.environment.web_subdomain_name
  content = aws_cloudfront_distribution.spa.domain_name
  ttl     = 1 # "automatic"
  # CloudFront terminates TLS with its own ACM certificate, so Cloudflare must stay out of the path.
  proxied = false
}
