# The SPA's public host points at its CloudFront distribution. Not proxied: CloudFront terminates TLS
# with the ACM certificate above, so Cloudflare must stay out of the path.
resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = module.common.web_subdomain_name
  content = aws_cloudfront_distribution.spa.domain_name
  ttl     = 1 # "automatic"
  proxied = false
}
