# The API runs as a container Lambda built from the shared ECR repo (created by
# the root infra). Armeria listens on 8080; the AWS Lambda Web Adapter baked
# into the image bridges Lambda invocations to it.
data "aws_ecr_repository" "api" {
  name = "${module.common.aws_resource_prefix}-api"
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
  image_uri     = "${data.aws_ecr_repository.api.repository_url}:${var.image_tag}"
  architectures = ["x86_64"]

  # A JVM cold start needs headroom; more memory also means more vCPU, which
  # shortens it. Timeout covers a cold start plus Neon's own resume.
  memory_size = 2048
  timeout     = 30

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
