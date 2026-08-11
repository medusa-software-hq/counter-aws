# Container registry for the API image. One repository, shared across
# environments (images are tagged per environment + commit); created only in the
# prod workspace, like the CI/CD role.
resource "aws_ecr_repository" "api" {
  count = local.create_shared_aws

  name = "${module.common.aws_resource_prefix}-api"

  image_scanning_configuration {
    scan_on_push = true
  }
}
