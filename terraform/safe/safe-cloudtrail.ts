resource "aws_kms_key" "cloudtrail_key" {
  description         = "KMS key for secure CloudTrail logs"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-policy-cloudtrail",
    Statement = [
      {
        Sid    = "Allow CloudTrail to use the key",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:ap-northeast-2:311278774159:trail/secure-trail"
          }
        }
      },
      {
        Sid    = "Allow account to administer the key",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::311278774159:root"
        },
        Action = "kms:*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "cloudtrail_alias" {
  name          = "alias/cloudtrail-key"                    #kms key name
  target_key_id = aws_kms_key.cloudtrail_key.id
}

data "aws_cloudwatch_log_group" "secure_log_group" {        #백업 로그 그룹 (rds)
  name = "/aws/rds/instance/safe-db/error"
}

resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name = "cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {        #새 IAM role 생성
  name = "cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${data.aws_cloudwatch_log_group.secure_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "secure_trail" {              
  name                          = "secure-trail"          #trail name
  s3_bucket_name                = "safe-s3-monitor"       #s3 bucket name
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  enable_logging                = true
  kms_key_id                    = aws_kms_key.cloudtrail_key.arn

  cloud_watch_logs_group_arn = "arn:aws:logs:ap-northeast-2:311278774159:log-group:/aws/rds/instance/safe-db/error:*" 
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}

resource "aws_sns_topic" "cloudtrail_alerts" {
  name = "cloudtrail-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.cloudtrail_alerts.arn
  protocol  = "email"
  endpoint  = "oscarjinho.kim@gmail.com"          #보고 받을 메일 주소
}

resource "aws_cloudwatch_log_metric_filter" "trail_filter" {
  name           = "trail-error-filter"
  log_group_name = data.aws_cloudwatch_log_group.secure_log_group.name
  pattern        = "{ $.errorCode = * }"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "CloudTrail"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "trail_error_alarm" {
  alarm_name          = "cloudtrail-error-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.trail_filter.metric_transformation[0].name
  namespace           = "CloudTrail"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "CloudTrail detected error"
  alarm_actions       = [aws_sns_topic.cloudtrail_alerts.arn]
}
