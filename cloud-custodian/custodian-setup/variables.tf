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

# ================================
# Lambda 함수 변수
# ================================

variable "mailer_lambda_name" {
  description = "Name of the c7n-mailer Lambda function"
  type        = string
  default     = "whs3-c7n-mailer"
}

variable "custodian_lambda_name" {
  type = string
  default = "whs3-custodian-cloudtrail"
}

# ================================
# 알림 설정
# ================================

variable "good_slack"    { type = string }
variable "warning_slack" { type = string }
variable "danger_slack"  { type = string }

