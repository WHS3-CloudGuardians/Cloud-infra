# terraform\main.tf

#########################################
# Custodian Notification Queue (SQS)
# → 다른 모듈들이 SQS ARN을 참조함
#########################################

module "custodian_sqs" {
  source                    = "./modules/custodian-sqs"
  queue_name                = var.queue_name
  dlq_name                  = var.dlq_name
  message_retention_seconds = var.message_retention_seconds
  max_receive_count         = var.max_receive_count
}

#########################################
# IAM Role & Policies for Custodian / Mailer
#########################################

module "custodian_iam" {
  source                   = "./modules/custodian-iam"
  aws_region               = var.aws_region
  account_id               = var.account_id
  lambda_role_name         = var.lambda_role_name
  mailer_role_name         = var.mailer_role_name
  sqs_queue_arn            = module.custodian_sqs.custodian_notify_queue_arn
  enable_config_integration = var.enable_config_integration
}

#########################################
# CloudTrail + S3 Logging for Custodian
#########################################

module "custodian_trail" {
  source                    = "./modules/custodian-trail"
  account_id                = var.account_id
  aws_region                = var.aws_region
  trail_bucket_name         = var.trail_bucket_name

  queue_name                = var.queue_name
  dlq_name                  = var.dlq_name
  message_retention_seconds = var.message_retention_seconds
  max_receive_count         = var.max_receive_count

  lambda_role_name          = var.lambda_role_name
  mailer_role_name          = var.mailer_role_name
  sqs_queue_arn             = module.custodian_sqs.custodian_notify_queue_arn
}

module "custodian_mailer" {
  source            = "./modules/custodian-mailer"
  aws_region        = var.aws_region
  account_id        = var.account_id
  mailer_role_name  = var.mailer_role_name
  mailer_lambda_name = "c7n-mailer"
  queue_name        = var.queue_name
  queue_url         = module.custodian_sqs.custodian_notify_queue_url
  sqs_queue_arn     = module.custodian_sqs.custodian_notify_queue_arn
}
