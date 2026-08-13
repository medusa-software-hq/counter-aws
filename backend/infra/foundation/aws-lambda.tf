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

  # A GraalVM-native cold start runs in a few hundred milliseconds, so modest memory (which also sets
  # the vCPU share) and a short timeout are ample. The counter is held in memory for now, so no DB
  # connection to establish at startup.
  memory_size = 512
  timeout     = 10

  depends_on = [aws_iam_role_policy_attachment.api_basic_execution]
}

# The API is fronted by an API Gateway HTTP API: a Lambda-proxy integration with payload format 2.0,
# so the function receives the same APIGatewayV2HTTPEvent it did from the function URL — no handler
# change. Access control (a Cognito JWT authorizer) lands in a later slice; for now every route is
# open. CloudFront points its /api behavior at this endpoint (see the web foundation).
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

# A catch-all route: the Micronaut router in the function owns the actual paths (/counter/*).
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
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
