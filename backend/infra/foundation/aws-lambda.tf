# The API runs as a container Lambda built from the shared ECR repo (created by
# the root infra). Armeria listens on 8080; the AWS Lambda Web Adapter baked
# into the image bridges Lambda invocations to it.
locals {
  # Deterministic ECR repo URL, built rather than looked up via a data source
  # (which would need ecr:DescribeImages on the CI role).
  ecr_repository_url = "${module.common.aws_account_id}.dkr.ecr.${module.common.aws_primary_location}.amazonaws.com/${module.common.aws_resource_prefix}-api"
}

resource "aws_iam_role" "api" {
  name = "${module.common.aws_resource_prefix}-api${module.common.resource_name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_basic_execution" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read only this environment's DB connection-string secret.
resource "aws_iam_role_policy" "api_read_database_url" {
  name = "read-database-url"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.database_url.arn
    }]
  })
}

resource "aws_lambda_function" "api" {
  function_name = "${module.common.aws_resource_prefix}-api${module.common.resource_name_suffix}"
  role          = aws_iam_role.api.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_repository_url}:${var.image_tag}"
  architectures = ["x86_64"]

  # A full cold start (JVM + AWS SDK + Neon resume + Flyway) runs ~40s, so the
  # timeout is generous; more memory = more vCPU, shortening it. SnapStart is the real fix (epic follow-up).
  memory_size = 2048
  timeout     = 90

  environment {
    variables = {
      PORT                      = "8080"
      AWS_LWA_PORT              = "8080"
      CORS_ALLOWED_ORIGIN_REGEX = "https://[a-z0-9-]+\\.medusa\\.software"
      # The app fetches the Neon connection string from Secrets Manager itself.
      DATABASE_URL_SECRET_ARN = aws_secretsmanager_secret.database_url.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.api_basic_execution]
}

# Private for now — reachable only by callers with IAM permission. The public
# entry point (API Gateway + Cognito authorizer) comes in a later issue.
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "AWS_IAM"
}

output "api_function_name" {
  value = aws_lambda_function.api.function_name
}

output "api_function_url" {
  value = aws_lambda_function_url.api.function_url
}
