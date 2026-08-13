# The account-wide GitHub Actions OIDC provider lives in the meta repo; look it
# up here rather than owning it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  # The CI/CD role + registry are account-level singletons for this variant, but
  # this root runs per environment (workspace). Create them only in the prod
  # (default) workspace so a staging apply doesn't collide on the shared names.
  create_shared_aws = module.common.environment == "prod" ? 1 : 0

  aws_state_bucket_arn = "arn:aws:s3:::${module.common.aws_state_bucket_name}"
  # Counter's state lives under this prefix (and under env:/<workspace>/… for
  # non-default workspaces).
  aws_state_prefix = "projects/${module.common.project_base_name}/${module.common.project_variant}"
}

# Role GitHub Actions assumes via OIDC to deploy this variant, scoped to the repo.
resource "aws_iam_role" "cicd" {
  count = local.create_shared_aws

  name = "${module.common.aws_resource_prefix}-github-actions"

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
            "repo:${module.common.gh_organization_name}/${module.common.gh_repo_name}:*",
            "repo:${module.common.gh_organization_name}@*/${module.common.gh_repo_name}@*:*",
          ]
        }
      }
    }]
  })
}

# What CI/CD may do today: read/write this variant's Terraform state (its prefix
# in the shared bucket) and push container images. Service permissions (Lambda,
# CloudFront, …) are added by the issues that introduce those services.
resource "aws_iam_role_policy" "cicd" {
  count = local.create_shared_aws

  name = "state-and-ecr"
  role = aws_iam_role.cicd[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = local.aws_state_bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = ["${local.aws_state_prefix}/*", "env:/*/${local.aws_state_prefix}/*"] }
        }
      },
      {
        Sid    = "TerraformStateObjects"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "${local.aws_state_bucket_arn}/${local.aws_state_prefix}/*",
          "${local.aws_state_bucket_arn}/env:/*/${local.aws_state_prefix}/*",
        ]
      },
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
        ]
        Resource = "arn:aws:ecr:${module.common.aws_primary_location}:${module.common.aws_account_id}:repository/${module.common.aws_resource_prefix}-*"
      },
      {
        # Apply the API foundation from CI: manage this variant's Lambda + URL.
        Sid      = "LambdaManage"
        Effect   = "Allow"
        Action   = "lambda:*"
        Resource = "arn:aws:lambda:${module.common.aws_primary_location}:${module.common.aws_account_id}:function:${module.common.aws_resource_prefix}-*"
      },
      {
        # Apply the API foundation from CI: manage this variant's API Gateway HTTP API. Creating an
        # API is apigateway:POST on the collection ARN (/apis); everything else (routes, integration,
        # authorizer, stage, tags) lives under the API's own ARN (/apis/*).
        Sid    = "ApiGatewayManage"
        Effect = "Allow"
        Action = "apigateway:*"
        Resource = [
          "arn:aws:apigateway:${module.common.aws_primary_location}::/apis",
          "arn:aws:apigateway:${module.common.aws_primary_location}::/apis/*",
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
        Resource = "arn:aws:iam::${module.common.aws_account_id}:role/${module.common.aws_resource_prefix}-*"
      },
      {
        Sid      = "LambdaPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${module.common.aws_account_id}:role/${module.common.aws_resource_prefix}-*"
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
        Resource = "arn:aws:secretsmanager:${module.common.aws_primary_location}:${module.common.aws_account_id}:secret:${module.common.aws_resource_prefix}-*"
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
        Resource = "arn:aws:s3:::${module.common.aws_resource_prefix}-web*"
      },
      {
        Sid    = "WebBucketObjects"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${module.common.aws_resource_prefix}-web*",
          "arn:aws:s3:::${module.common.aws_resource_prefix}-web*/*",
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
