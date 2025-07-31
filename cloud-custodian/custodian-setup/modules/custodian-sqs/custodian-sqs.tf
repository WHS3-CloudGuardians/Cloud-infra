# custodian-setup\modules\custodian-sqs\custodian-sqs.tf

# ================================
# Variables
# ================================

variable "queue_name" {
  type        = string
  description = "Name of the main SQS queue for Custodian notifications"
}

variable "dlq_name" {
  type        = string
  description = "Name of the Dead Letter Queue"
}

variable "message_retention_seconds" {
  type        = number
  description = "How long (in seconds) messages are retained in the queue"
}

variable "max_receive_count" {
  type        = number
  description = "Max number of receives before sending to DLQ"
}

# ================================
# SQS Queues
# ================================

# Dead Letter Queue (DLQ) for failed Custodian notification processing
resource "aws_sqs_queue" "custodian_dlq_queue" {
  name                       = var.dlq_name
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = 310
}

# Primary Notification Queue with redrive policy to DLQ
resource "aws_sqs_queue" "custodian_notify_queue" {
  name                       = var.queue_name
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = 310
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.custodian_dlq_queue.arn
    maxReceiveCount     = var.max_receive_count
  })

  depends_on = [aws_sqs_queue.custodian_dlq_queue]
}

# ================================
# Outputs
# ================================

# Main Queue Outputs
output "custodian_notify_queue_url" {
  description = "URL of the SQS queue for Custodian notifications"
  value       = aws_sqs_queue.custodian_notify_queue.url
}

output "custodian_notify_queue_arn" {
  description = "ARN of the SQS queue for Custodian notifications"
  value       = aws_sqs_queue.custodian_notify_queue.arn
}

# Dead Letter Queue Outputs
output "custodian_dlq_queue_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.custodian_dlq_queue.url
}

output "custodian_dlq_queue_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = aws_sqs_queue.custodian_dlq_queue.arn
}
