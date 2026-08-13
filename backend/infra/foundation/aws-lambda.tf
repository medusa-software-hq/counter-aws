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

  filename         = local.lambda_zip
  source_code_hash = filebase64sha256(local.lambda_zip)

  # A GraalVM-native cold start runs in a few hundred milliseconds, so modest memory (which also sets
  # the vCPU share) and a short timeout are ample. The counter is held in memory for now, so no DB
  # connection to establish at startup.
  memory_size = 512
  timeout     = 10

  depends_on = [aws_iam_role_policy_attachment.api_basic_execution]
}

# IAM-authorized: the only caller is this account's CloudFront distribution, which signs requests via
# an Origin Access Control (see the web foundation). No public unsigned access.
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "AWS_IAM"
}

# Let CloudFront (OAC) invoke the function URL. Scoped to any distribution in this account by
# wildcard SourceArn, which avoids a circular dependency on the distribution id that lives in the
# web foundation's separate state.
resource "aws_lambda_permission" "cloudfront_invoke_url" {
  statement_id           = "AllowCloudFrontInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.api.function_name
  principal              = "cloudfront.amazonaws.com"
  function_url_auth_type = "AWS_IAM"
  source_arn             = "arn:aws:cloudfront::${module.common.aws_account_id}:distribution/*"
}

output "api_function_name" {
  value = aws_lambda_function.api.function_name
}

output "api_function_url" {
  value = aws_lambda_function_url.api.function_url
}
