provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_kms_key" "cloudwatch_key" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::311278774159:user/jinho"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowCloudWatchLogsService",
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.ap-northeast-2.amazonaws.com"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_kms_alias" "cloudwatch_alias" {
  name          = "alias/cloudwatch-key"                      #kms key name
  target_key_id = aws_kms_key.cloudwatch_key.key_id
}

resource "aws_cloudwatch_log_group" "secure_log_group" {
  name              = "safe-cloudwatch-log_group"             #새로 생성할 로그 그룹 이름
  retention_in_days = 90                                      #로그 보존 일 수
  kms_key_id        = aws_kms_key.cloudwatch_key.arn
}

resource "aws_sns_topic" "rds_log_alerts" {
  name = "rds-log-alert-topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.rds_log_alerts.arn
  protocol  = "email"
  endpoint  = "oscarjinho.kim@gmail.com"                      #알림 받을 메일 주소
}

resource "aws_cloudwatch_log_metric_filter" "rds_error_filter" {
  name           = "rds-error-filter"
  log_group_name = "/aws/rds/instance/safe-db/error"          #백업을 위한 그룹
  pattern        = "ERROR"

  metric_transformation {
    name      = "RdsErrorCount"
    namespace = "RDS/Logs"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_error_alarm" {
  alarm_name          = "RdsErrorAlarm"
  metric_name         = "RdsErrorCount"
  namespace           = "RDS/Logs"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.rds_log_alerts.arn]
  treat_missing_data  = "notBreaching"
}

# RDS 백업 자동화 -> Lambda 추가 필요함
