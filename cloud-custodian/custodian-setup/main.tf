# custodian-setup\main.tf

# ================================
# Custodian Notification Queue (SQS)
# → 다른 모듈들이 SQS ARN을 참조함
# ================================

module "custodian_sqs" {
  source                    = "./modules/custodian-sqs"
  queue_name                = var.queue_name
  dlq_name                  = var.dlq_name
  message_retention_seconds = var.message_retention_seconds
  max_receive_count         = var.max_receive_count
}

# ================================
# IAM Role & Policies for Custodian / Mailer
# ================================

module "custodian_iam" {
  source           = "./modules/custodian-iam"
  aws_region       = var.aws_region
  account_id       = var.account_id
  lambda_role_name = var.lambda_role_name
  mailer_role_name = var.mailer_role_name
  sqs_queue_arn    = module.custodian_sqs.custodian_notify_queue_arn
}

# ================================
# CloudTrail + S3 Logging for Custodian
# ================================

module "custodian_trail" {
  source            = "./modules/custodian-trail"
  account_id        = var.account_id
  aws_region        = var.aws_region
  trail_bucket_name = "whs3-cloudtrail-logs-${var.account_id}"
}

# ================================
# c7n-mailer Lambda Function
# ================================

module "custodian_mailer" {
  source             = "./modules/custodian-mailer"
  aws_region         = var.aws_region
  account_id         = var.account_id
  mailer_role_name   = var.mailer_role_name
  mailer_lambda_name = var.mailer_lambda_name
  queue_url          = module.custodian_sqs.custodian_notify_queue_url
  sqs_queue_arn      = module.custodian_sqs.custodian_notify_queue_arn

  good_slack    = var.good_slack
  warning_slack = var.warning_slack
  danger_slack  = var.danger_slack
}

# ================================
# CloudTrail-based Custodian Lambda
# ================================

module "custodian_cloudtrail" {
  source          = "./modules/custodian-cloudtrail"
  function_name = var.custodian_lambda_name
  lambda_role_arn = module.custodian_iam.custodian_lambda_role_arn
  queue_url       = module.custodian_sqs.custodian_notify_queue_url
}
