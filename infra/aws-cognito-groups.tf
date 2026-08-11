# Pre-token-generation Lambda that populates `cognito:groups` from the user's IAM
# Identity Center group memberships (IdC SAML can't carry group names — see the
# handler). Fires on every token issuance for this pool.

data "aws_ssoadmin_instances" "this" {}

data "archive_file" "pretoken" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/cognito-pretoken"
  output_path = "${path.module}/.build/cognito-pretoken.zip"
}

resource "aws_iam_role" "pretoken" {
  name = "${local.cognito_name}-pretoken"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "pretoken_basic_execution" {
  role       = aws_iam_role.pretoken.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read-only directory lookups: resolve the user and their group names.
resource "aws_iam_role_policy" "pretoken_identitystore" {
  name = "read-identity-store"
  role = aws_iam_role.pretoken.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "identitystore:GetUserId",
        "identitystore:ListGroupMembershipsForMember",
        "identitystore:DescribeGroup",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "pretoken" {
  function_name = "${local.cognito_name}-pretoken"
  role          = aws_iam_role.pretoken.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  timeout       = 10

  filename         = data.archive_file.pretoken.output_path
  source_code_hash = data.archive_file.pretoken.output_base64sha256

  environment {
    variables = {
      IDENTITY_STORE_ID = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
    }
  }

  depends_on = [aws_iam_role_policy_attachment.pretoken_basic_execution]
}

resource "aws_lambda_permission" "pretoken_cognito" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pretoken.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}
