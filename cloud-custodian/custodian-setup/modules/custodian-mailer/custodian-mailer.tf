# custodian-setup\modules\custodian-mailer\custodian-mailer.tf

# ================================
# Variables
# ================================

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "mailer_role_name" {
  description = "Name of the c7n-mailer IAM role"
  type        = string
}

variable "mailer_lambda_name" {
  description = "Name of the c7n-mailer Lambda function"
  type        = string
}

variable "queue_url" {
  description = "URL of the SQS queue for notifications"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue for notifications"
  type        = string
}

variable "good_slack"    { type = string }
variable "warning_slack" { type = string }
variable "danger_slack"  { type = string }

# ================================
# Lambda Function - c7n-mailer
# ================================

resource "aws_lambda_function" "c7n_mailer_lambda" {
  function_name = var.mailer_lambda_name
  role          = "arn:aws:iam::${var.account_id}:role/${var.mailer_role_name}"
  handler       = "mailer.handler"
  runtime       = "python3.11"
  timeout       = 300
  memory_size   = 256
  publish       = true
  filename      = "${path.module}/c7n-mailer.zip"

  environment {   
    variables = {
      QUEUE_URL     = var.queue_url
      REGION        = var.aws_region
      ACCOUNT_ID    = var.account_id

      GOOD_SLACK    = var.good_slack
      WARNING_SLACK = var.warning_slack
      DANGER_SLACK  = var.danger_slack
    }
  }
}

# ================================
# Lambda Permission to Read from SQS
# ================================

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.c7n_mailer_lambda.arn
  batch_size       = 10
  enabled          = true
}

# ================================
# Outputs
# ================================

output "mailer_lambda_arn" {
  value = aws_lambda_function.c7n_mailer_lambda.arn
}
