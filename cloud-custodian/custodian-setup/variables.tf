# custodian-setup\variables.tf

# ================================
# 기본 환경 설정
# ================================

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ================================
# IAM Role 변수
# ================================

variable "lambda_role_name" {
  description = "Name of the Custodian Lambda IAM role"
  type        = string
  default     = "whs3-custodian-lambda-role"
}

variable "mailer_role_name" {
  description = "Name of the c7n-mailer IAM role"
  type        = string
  default     = "whs3-c7n-mailer-role"
}

# ================================
# SQS Queue 변수
# ================================

variable "queue_name" {
  description = "Name of the SQS queue for Custodian notifications"
  type        = string
  default     = "whs3-security-alert-queue"
}

variable "dlq_name" {
  description = "Name of the Dead Letter Queue"
  type        = string
  default     = "whs3-security-alert-dlq"
}

variable "message_retention_seconds" {
  description = "Message retention period for the SQS queue (in seconds)"
  type        = number
  default     = 864000  # 10 days
}

variable "max_receive_count" {
  description = "Max number of receives before sending message to DLQ"
  type        = number
  default     = 3
}

variable "trail_bucket_name" {
  description = "Fully qualified S3 bucket name for CloudTrail logs (must be globally unique)"
  type        = string
  default     = "" 
}

