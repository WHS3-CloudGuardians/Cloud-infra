# terraform\variables.tf

#########################################
# 기본 환경 설정
#########################################

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

#########################################
# IAM Role 변수 (이름 지정)
#########################################

variable "lambda_role_name" {
  description = "Name of the Custodian Lambda IAM role"
  type        = string
  default     = "custodian-lambda-role"
}

variable "mailer_role_name" {
  description = "Name of the c7n-mailer IAM role"
  type        = string
  default     = "c7n-mailer-role"
}

#########################################
# SQS Queue 변수
#########################################

variable "queue_name" {
  description = "Name of the SQS queue for Custodian notifications"
  type        = string
  default     = "custodian-notify-queue"
}

variable "dlq_name" {
  description = "Name of the Dead Letter Queue"
  type        = string
  default     = "custodian-notify-dlq"
}

variable "message_retention_seconds" {
  description = "Message retention period for the SQS queue (in seconds)"
  type        = number
  default     = 1209600  # 14 days
}

variable "max_receive_count" {
  description = "Max number of receives before sending message to DLQ"
  type        = number
  default     = 5
}

# SQS ARN (출력값으로 전달될 수 있음)
variable "sqs_queue_arn" {
  description = "ARN of the SQS queue used for Custodian notifications"
  type        = string
}

#########################################
# CloudTrail 로그용 S3 버킷
#########################################

variable "trail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  type        = string
  default     = "dev-test-cloudtrail-logs-bucket"
}

#########################################
# Config 통합 여부 (선택)
#########################################

variable "enable_config_integration" {
  description = "Whether to enable AWS Config integration for Custodian"
  type        = bool
  default     = false
}

variable "mailer_lambda_name" {
  description = "Name of the c7n-mailer Lambda function"
  type        = string
  default     = "c7n-mailer"
}
