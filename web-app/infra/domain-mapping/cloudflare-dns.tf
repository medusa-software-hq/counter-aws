# Points the web host at the CloudFront distribution. DNS-only (not proxied):
# CloudFront terminates TLS with the ACM certificate the foundation validated,
# so Cloudflare must not sit in front of it.
resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = module.common.web_subdomain_name
  content = data.terraform_remote_state.web_foundation.outputs.cloudfront_domain_name
  ttl     = 1 # "automatic"
  proxied = false
}
