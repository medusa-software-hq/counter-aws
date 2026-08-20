# The Neon connection string, held in Secrets Manager and read by the Lambda at
# startup — so the DB password never sits in the function's plaintext config.
resource "aws_secretsmanager_secret" "database_url" {
  name = "${module.global.aws_resource_prefix}-database-url${module.environment.resource_name_suffix}"

  # Immediate re-create after a delete, rather than the default 30-day recovery window.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = local.database_jdbc_url
}
