# custodian-setup\main.tf

# ================================
# CloudTrail 설정
# ================================

module "custodian_trail" {
  source            = "./modules/custodian-trail"
  account_id        = var.account_id
  aws_region        = var.aws_region
  trail_bucket_name = var.trail_bucket_name
}

# ================================
# SQS 큐 설정
# ================================

module "custodian_sqs" {
  source                    = "./modules/custodian-sqs"
  queue_name                = var.queue_name
  dlq_name                  = var.dlq_name
  message_retention_seconds = var.message_retention_seconds
  max_receive_count         = var.max_receive_count
}

# ================================
# IAM 역할 설정
# ================================

module "custodian_iam" {
  source             = "./modules/custodian-iam"
  account_id         = var.account_id
  aws_region         = var.aws_region
  lambda_role_name   = var.lambda_role_name
  mailer_role_name   = var.mailer_role_name
  sqs_queue_arn      = module.custodian_sqs.custodian_notify_queue_arn
}

# ================================
# EventBridge 기본 설정 (CloudTrail 이벤트용)
# ================================

# CloudTrail 이벤트를 EventBridge로 전달하기 위한 기본 규칙
resource "aws_cloudwatch_event_rule" "cloudtrail_events" {
  name        = "custodian-cloudtrail-events"
  description = "Capture CloudTrail events for Custodian CloudTrail-mode policies"
  
  event_pattern = jsonencode({
    source = ["aws.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
  })
}
