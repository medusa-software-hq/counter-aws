# API Gateway needs its account-level service-linked role to create custom domain names. The CI/CD
# role can't create service-linked roles (that requires account-wide iam:CreateServiceLinkedRole), so
# provision the role here in root infra, applied once with operator credentials.
resource "aws_iam_service_linked_role" "apigateway" {
  aws_service_name = "ops.apigateway.amazonaws.com"
}
