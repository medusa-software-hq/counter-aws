# The account-wide GitHub Actions OIDC provider lives in the meta repo; look it
# up here rather than owning it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  aws_state_bucket_arn = "arn:aws:s3:::${module.global.aws_state_bucket_name}"
  # This project's state lives under this prefix (and under env:/<workspace>/… for
  # non-default workspaces).
  aws_state_prefix = module.global.aws_state_prefix

  # CI/CD applies only the two app foundations, so it reaches only their state —
  # not root/shared or root/env-matrix, which the operator applies. root/shared
  # is what defines this very role, so letting CI write it would make the role
  # able to widen itself.
  aws_cicd_state_prefixes = [
    "${local.aws_state_prefix}/backend/foundation",
    "${local.aws_state_prefix}/web-app/foundation",
  ]
  aws_cicd_state_object_arns = flatten([
    for prefix in local.aws_cicd_state_prefixes : [
      "${local.aws_state_bucket_arn}/${prefix}/*",
      "${local.aws_state_bucket_arn}/env:/*/${prefix}/*",
    ]
  ])
  # Terraform enumerates workspaces by listing the bare `env:/` prefix, so that prefix has to be
  # allowed on its own — a condition naming only the per-root prefixes below denies the listing, and
  # `terraform workspace select <name>` then reports the workspace as non-existent. The listing
  # returns key names under `env:/` for every project in the shared bucket; reading any of them is
  # still governed by the object statement, which stays scoped to this variant's two foundations.
  aws_cicd_state_list_prefixes = concat(["env:/"], flatten([
    for prefix in local.aws_cicd_state_prefixes : ["${prefix}/*", "env:/*/${prefix}/*"]
  ]))
}

# Role GitHub Actions assumes via OIDC to deploy this variant, scoped to the repo.
resource "aws_iam_role" "cicd" {
  name = "${module.global.aws_resource_prefix}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Match both the legacy mutable subject and GitHub's newer immutable one
        # (`repo:org@<org-id>/repo@<repo-id>:…`), which this repo now issues.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${module.global.gh_organization_name}/${module.global.gh_repo_name}:*",
            "repo:${module.global.gh_organization_name}@*/${module.global.gh_repo_name}@*:*",
          ]
        }
      }
    }]
  })
}

# What CI/CD may do today: read/write the Terraform state of the two foundations
# it applies, plus the service permissions those foundations need.
resource "aws_iam_role_policy" "cicd" {
  name = "state-and-services"
  role = aws_iam_role.cicd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = local.aws_state_bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = local.aws_cicd_state_list_prefixes }
        }
      },
      {
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = local.aws_cicd_state_object_arns
      },
      {
        # Apply the API foundation from CI: manage this variant's Lambda + URL.
        Sid      = "LambdaManage"
        Effect   = "Allow"
        Action   = "lambda:*"
        Resource = "arn:aws:lambda:${module.global.aws_primary_location}:${module.global.aws_account_id}:function:${module.global.aws_resource_prefix}-*"
      },
      {
        # Apply the API foundation from CI. Creating an API is apigateway:POST on the collection ARN
        # (/apis); everything else (routes, integration, authorizer, stage, tags) lives under the
        # API's own ARN. An API's ARN carries its generated id, not its name, so /apis/* cannot be
        # narrowed to this variant. Custom domains are a separate collection and *are* named, so
        # they are scoped to this variant's hosts across environments (api.<project>-<variant>…).
        Sid    = "ApiGatewayManage"
        Effect = "Allow"
        Action = "apigateway:*"
        Resource = [
          "arn:aws:apigateway:${module.global.aws_primary_location}::/apis",
          "arn:aws:apigateway:${module.global.aws_primary_location}::/apis/*",
          "arn:aws:apigateway:${module.global.aws_primary_location}::/domainnames",
          "arn:aws:apigateway:${module.global.aws_primary_location}::/domainnames/${module.global.api_subdomain_prefix}*",
        ]
      },
      {
        # Manage the Lambda execution role and pass it to the Lambda service.
        Sid    = "LambdaRoleManage"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:DeleteRole",
          "iam:TagRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
        ]
        Resource = "arn:aws:iam::${module.global.aws_account_id}:role/${module.global.aws_resource_prefix}-*"
      },
      {
        Sid      = "LambdaPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${module.global.aws_account_id}:role/${module.global.aws_resource_prefix}-*"
        Condition = {
          StringEquals = { "iam:PassedToService" = "lambda.amazonaws.com" }
        }
      },
      {
        # Manage this variant's secrets (the DB connection string).
        Sid    = "SecretsManage"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource",
          "secretsmanager:DeleteSecret",
          "secretsmanager:GetResourcePolicy",
        ]
        Resource = "arn:aws:secretsmanager:${module.global.aws_primary_location}:${module.global.aws_account_id}:secret:${module.global.aws_resource_prefix}-*"
      },
      {
        # Manage this variant's SPA bucket. `s3:Get*` (bucket-scoped, so it does
        # not cover object reads) covers the many bucket sub-configs the AWS
        # provider reads on every refresh without enumerating each one.
        Sid    = "WebBucketManage"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:Get*",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketOwnershipControls",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketTagging",
          "s3:PutBucketVersioning",
        ]
        Resource = "arn:aws:s3:::${module.global.aws_resource_prefix}-web*"
      },
      {
        Sid    = "WebBucketObjects"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${module.global.aws_resource_prefix}-web*",
          "arn:aws:s3:::${module.global.aws_resource_prefix}-web*/*",
        ]
      },
      {
        # Manage the SPA's CloudFront distribution + its origin access control,
        # and invalidate the edge cache on each deploy. CloudFront is a global
        # service and does not support resource-scoped IAM, so this is on "*".
        Sid    = "CloudFrontManage"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:ListTagsForResource",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          # The /api behavior strips its path prefix with a CloudFront Function.
          "cloudfront:CreateFunction",
          "cloudfront:DescribeFunction",
          "cloudfront:GetFunction",
          "cloudfront:UpdateFunction",
          "cloudfront:PublishFunction",
          "cloudfront:DeleteFunction",
        ]
        Resource = "*"
      },
      {
        # Request + validate the ACM certificate CloudFront serves (us-east-1).
        # ACM certificate ARNs are server-generated, so RequestCertificate and
        # the describe/tag calls require "*".
        Sid    = "AcmManage"
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DescribeCertificate",
          "acm:ListTagsForCertificate",
          "acm:AddTagsToCertificate",
          "acm:DeleteCertificate",
        ]
        Resource = "*"
      },
    ]
  })
}

# The role's ARN, published where the deploy workflows can read it. A workflow has to assume this
# role before it can read any Terraform state, so the one value it cannot look up is this one.
resource "github_actions_variable" "aws_cicd_role_arn" {
  repository    = data.github_repository.this.name
  variable_name = "AWS_CICD_ROLE_ARN"
  value         = aws_iam_role.cicd.arn
}
