# The API runs as a GraalVM-native binary on a Lambda custom runtime (provided.al2023). The deploy
# workflow builds the native `bootstrap` zip before applying.
locals {
  # Produced by `./gradlew :backend:api:handler:buildNativeLambda`.
  lambda_zip = "${path.module}/../../api/handler/build/libs/handler-1.0.0-lambda.zip"
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

# Read only this environment's DB connection-string secret at startup.
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

  package_type  = "Zip"
  runtime       = "provided.al2023"
  handler       = "bootstrap"
  architectures = ["x86_64"]

  filename = local.lambda_zip
  # The deploy workflow builds the zip before applying; `terraform validate` (CI, no build) tolerates
  # its absence, and every real plan/apply computes the true hash so a rebuilt binary redeploys.
  source_code_hash = fileexists(local.lambda_zip) ? filebase64sha256(local.lambda_zip) : null

  # A GraalVM-native cold start is fast, but the first request may also wake the serverless Neon
  # database and open a TLS connection, so allow some headroom. More memory also raises the vCPU
  # share, which shortens the connect.
  memory_size = 512
  timeout     = 30

  # The Lambda fetches the Neon connection string from Secrets Manager itself (Lambda has no
  # secret-to-env mapping), so the DB password never sits in the function's plaintext config.
  environment {
    variables = {
      DATABASE_URL_SECRET_ARN = aws_secretsmanager_secret.database_url.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.api_basic_execution]
}

# The API is fronted by an API Gateway HTTP API: a Lambda-proxy integration with payload format 2.0.
# Every route is gated by the Cognito JWT authorizer below.
resource "aws_apigatewayv2_api" "api" {
  name          = "${module.common.aws_resource_prefix}-api${module.common.resource_name_suffix}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# Validates the caller's Cognito ID token natively — issuer (the user pool) and audience (the SPA
# app client) — and rejects anything unsigned/expired/mismatched with 401 before the function runs.
# This is the whole authentication story: the function does no token work.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.api.id
  name             = "${module.common.aws_resource_prefix}-cognito${module.common.resource_name_suffix}"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.cognito_issuer_url
    audience = [var.cognito_spa_client_id, var.cognito_cli_client_id]
  }
}

# A catch-all route, gated by the JWT authorizer: the Micronaut router in the function owns the
# actual paths (/counter/*).
resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

output "api_function_name" {
  value = aws_lambda_function.api.function_name
}

# The HTTP API's invoke endpoint (https://<id>.execute-api.<region>.amazonaws.com), consumed by the
# web foundation as the CloudFront /api origin.
output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}
