# modules/custodian-cloudtrail/custodian-cloudtrail.tf

# ================================
# Variables
# ================================

variable "queue_url" {
  description = "SQS queue URL for notify actions"
  type        = string
}

variable "function_name" {
  description = "Lambda function name for CloudTrail-triggered Custodian"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for the Custodian Lambda"
  type        = string
}

# ================================
# Lambda Function
# ================================

resource "aws_lambda_function" "custodian" {
  function_name = var.function_name
  filename      = "${path.module}/custodian.zip"
  role          = var.lambda_role_arn
  handler       = "custodian-lambda.handler"
  runtime       = "python3.11"
  memory_size   = 512
  timeout       = 300

  environment {
    variables = {
      QUEUE_URL = var.queue_url
    }
  }
}

# ================================
# EventBridge Rule & Target
# ================================

resource "aws_cloudwatch_event_rule" "cloudtrail_rule" {
  name = "${var.function_name}-rule"
  
  event_pattern = jsonencode({
    "source": ["aws.ec2", "aws.s3", "aws.iam", "aws.kms"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": [
        "ec2.amazonaws.com",
        "s3.amazonaws.com",
        "iam.amazonaws.com",
        "kms.amazonaws.com"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "publish_to_lambda" {
  rule      = aws_cloudwatch_event_rule.cloudtrail_rule.name
  target_id = var.function_name
  arn       = aws_lambda_function.custodian.arn
}

# ================================
# Lambda Permission
# ================================

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "Allow_${var.function_name}_From_EventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custodian.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudtrail_rule.arn
}

# ================================
# Outputs
# ================================

output "lambda_arn" {
  description = "ARN of the deployed Custodian Lambda"
  value       = aws_lambda_function.custodian.arn
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule for CloudTrail triggers"
  value       = aws_cloudwatch_event_rule.cloudtrail_rule.arn
}
