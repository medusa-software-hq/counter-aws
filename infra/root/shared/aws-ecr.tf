# Container registry for the API image. One repository, shared across
# environments (images are tagged per environment + commit).
resource "aws_ecr_repository" "api" {
  name = "${module.common.aws_resource_prefix}-api"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Let the Lambda service pull the API image (required even in-account for
# container Lambdas), scoped to this variant's functions.
resource "aws_ecr_repository_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaImagePull"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      Condition = {
        StringLike = {
          "aws:sourceArn" = "arn:aws:lambda:${module.common.aws_primary_location}:${module.common.aws_account_id}:function:${module.common.aws_resource_prefix}-*"
        }
      }
    }]
  })
}
