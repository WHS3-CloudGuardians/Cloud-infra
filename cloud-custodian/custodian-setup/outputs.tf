# custodian-setup\outputs.tf

# ================================
# IAM Role Outputs
# ================================

output "custodian_lambda_role_arn" {
  description = "ARN of the Custodian Lambda IAM role"
  value       = module.custodian_iam.custodian_lambda_role_arn
}

output "c7n_mailer_role_arn" {
  description = "ARN of the c7n-mailer IAM role"
  value       = module.custodian_iam.c7n_mailer_role_arn
}

# ================================
# SQS Queue Outputs
# ================================

output "custodian_notify_queue_url" {
  description = "URL of the SQS queue for Custodian notifications"
  value       = module.custodian_sqs.custodian_notify_queue_url
}

output "custodian_notify_queue_arn" {
  description = "ARN of the SQS queue for Custodian notifications"
  value       = module.custodian_sqs.custodian_notify_queue_arn
}

output "custodian_dlq_queue_url" {
  description = "URL of the Dead Letter Queue"
  value       = module.custodian_sqs.custodian_dlq_queue_url
}

output "custodian_dlq_queue_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = module.custodian_sqs.custodian_dlq_queue_arn
}

# ================================
# CloudTrail & S3 Bucket Outputs
# ================================

output "trail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = module.custodian_trail.trail_bucket_name
}

output "trail_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = module.custodian_trail.trail_bucket_arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = module.custodian_trail.cloudtrail_arn
}

# ================================
# Lambda Function Outputs
# ================================

output "custodian_lambda_arn" {
  description = "ARN of the Custodian CloudTrail Lambda function"
  value       = module.custodian_cloudtrail.lambda_arn
}

output "custodian_event_rule_arn" {
  description = "ARN of the EventBridge rule for CloudTrail triggers"
  value       = module.custodian_cloudtrail.event_rule_arn
}

output "mailer_lambda_arn" {
  description = "ARN of the c7n-mailer Lambda function"
  value       = module.custodian_mailer.mailer_lambda_arn
}
