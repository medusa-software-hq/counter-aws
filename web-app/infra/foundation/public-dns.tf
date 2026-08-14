# The SPA's public host points at its CloudFront distribution. Not proxied: CloudFront terminates TLS
# with the ACM certificate above, so Cloudflare must stay out of the path.
#
# This record used to live in a separate domain-mapping root; the import block adopts the existing
# record into this state on the next apply rather than recreating it, so there is no DNS gap. The
# block is a one-time migration aid — it can be dropped once the import has run.
import {
  to = cloudflare_dns_record.app
  id = "${var.cloudflare_zone_id}/dfb4c63e7786c3a015c32981a26c0d81"
}

resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  type    = "CNAME"
  name    = module.common.web_subdomain_name
  content = aws_cloudfront_distribution.spa.domain_name
  ttl     = 1 # "automatic"
  proxied = false
}
