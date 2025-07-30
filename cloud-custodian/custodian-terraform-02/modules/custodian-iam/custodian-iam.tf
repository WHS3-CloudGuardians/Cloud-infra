# terraform\modules\custodian-iam\custodian-iam.tf

############################
# Variables
############################

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "account_id" {
  type = string
}

variable "lambda_role_name" {
  description = "Name of the Custodian Lambda IAM role"
  type        = string
}

variable "mailer_role_name" {
  description = "Name of the c7n-mailer IAM role"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue for notifications"
  type        = string
}

variable "enable_config_integration" {
  type    = bool
  default = false
}

############################
# IAM Roles
############################

# Custodian Lambda 실행용 IAM Role
resource "aws_iam_role" "custodian_lambda_role" {
  name = var.lambda_role_name
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Mailer 실행용 IAM Role
resource "aws_iam_role" "c7n_mailer_role" {
  name               = var.mailer_role_name
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

############################
# IAM Role Policy Attachments (Managed Policies)
############################

# CloudWatch 로그 기록용 기본 정책 (Lambda용 AWS 관리형)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.custodian_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "mailer_basic_execution" {
  role       = aws_iam_role.c7n_mailer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################
# IAM Inline Policies - Custodian Lambda
############################

# 1. 리소스 조회 권한
resource "aws_iam_role_policy" "custodian_lambda_read_policy" {
  name = "${var.lambda_role_name}-read-policy"
  role = aws_iam_role.custodian_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:Describe*",
        "s3:GetBucket*",
        "s3:ListBucket*",
        "s3:GetObject*",
        "rds:Describe*",
        "lambda:List*",
        "lambda:Get*",
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "iam:ListRoles",
        "iam:ListUsers",
        "iam:GetRole",
        "iam:GetUser"
      ]
      Resource = "*"
    }]
  })
}

# 2. 자동조치(Write) 권한
resource "aws_iam_role_policy" "custodian_lambda_action_policy" {
  name = "${var.lambda_role_name}-action-policy"
  role = aws_iam_role.custodian_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:StopInstances",
        "ec2:StartInstances",
        "ec2:RebootInstances",
        "ec2:TerminateInstances",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "s3:PutBucketPolicy",
        "s3:PutBucketAcl",
        "s3:PutBucketVersioning",
        "s3:PutBucketEncryption",
        "s3:DeleteObject",
        "s3:DeleteBucket",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "rds:StopDBInstance",
        "rds:StartDBInstance",
        "rds:RebootDBInstance",
        "rds:CreateDBSnapshot",
        "rds:DeleteDBInstance"
      ]
      Resource = "*"
    }]
  })
}

# 3. CloudWatch 로그 기록 권한
resource "aws_iam_role_policy" "custodian_lambda_logs_policy" {
  name = "${var.lambda_role_name}-logs-policy"
  role = aws_iam_role.custodian_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/custodian-*"
    }]
  })
}

# 4. SQS 권한 (Slack 알림 연동용)
resource "aws_iam_role_policy" "custodian_lambda_sqs_access" {
  name   = "${var.lambda_role_name}-sqs-access"
  role   = aws_iam_role.custodian_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = var.sqs_queue_arn
    }]
  })
}

############################
# IAM Inline Policies - Mailer
############################

# 5. SES 권한 (Slack 대체 이메일 알림용)
resource "aws_iam_role_policy" "mailer_ses_policy" {
  name = "${var.mailer_role_name}-ses-policy"
  role = aws_iam_role.c7n_mailer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail",
        "ses:GetSendQuota",
        "ses:GetSendStatistics"
      ]
      Resource = "*"
    }]
  })
}

# 6. CloudWatch 로그 기록 권한
resource "aws_iam_role_policy" "mailer_logs_policy" {
  name = "${var.mailer_role_name}-logs-policy"
  role = aws_iam_role.c7n_mailer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/c7n-mailer-*"
    }]
  })
}

# 7. SQS 권한 (알림 수신)
resource "aws_iam_role_policy" "mailer_sqs_access" {
  name   = "${var.mailer_role_name}-sqs-access"
  role   = aws_iam_role.c7n_mailer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = var.sqs_queue_arn
    }]
  })
}

############################
# (옵션) Config 연동 정책
############################

resource "aws_iam_role_policy" "custodian_config_policy" {
  count = var.enable_config_integration ? 1 : 0
  name  = "${var.lambda_role_name}-config-policy"
  role  = aws_iam_role.custodian_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "config:GetComplianceDetailsByConfigRule",
        "config:GetComplianceDetailsByResource",
        "config:PutEvaluations"
      ]
      Resource = "*"
    }]
  })
}

############################
# Admin IAM Role with Full Access
############################

resource "aws_iam_role" "admin_role" {
  name = "admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "codebuild.amazonaws.com",
            "states.amazonaws.com",
            "ssm.amazonaws.com",
            "glue.amazonaws.com",
            "eks.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################
# Outputs
############################

output "custodian_lambda_role_arn" {
  description = "ARN of the Custodian Lambda IAM role"
  value       = aws_iam_role.custodian_lambda_role.arn
}

output "c7n_mailer_role_arn" {
  description = "ARN of the c7n-mailer IAM role"
  value       = aws_iam_role.c7n_mailer_role.arn
}
