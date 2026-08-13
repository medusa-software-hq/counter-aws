# Point the public API host at the regional API Gateway custom domain. Not proxied: API Gateway
# terminates TLS with its own ACM certificate for this host, so Cloudflare must not sit in the path.
resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = module.common.api_subdomain_name
  content = data.terraform_remote_state.api_foundation.outputs.api_domain_target
  ttl     = 1 # "automatic"
  proxied = false
}
