############################
# Variables
############################

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "mailer_role_name" {
  type = string
}

variable "mailer_lambda_name" {
  type    = string
  default = "c7n-mailer"
}

variable "queue_name" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "queue_url" {
  type = string
}

############################
# Lambda Function - c7n-mailer
############################

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
      SLACK_WEBHOOK = "env:/slack_webhook"
    }
  }
}

############################
# Lambda Permission to Read from SQS
############################

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn  = var.sqs_queue_arn
  function_name     = aws_lambda_function.c7n_mailer_lambda.arn
  batch_size        = 10
  enabled           = true
}

############################
# Outputs
############################

output "mailer_lambda_arn" {
  value = aws_lambda_function.c7n_mailer_lambda.arn
}
