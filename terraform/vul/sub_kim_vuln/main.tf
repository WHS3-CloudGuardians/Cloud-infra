# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#########################
# Variables
#########################
variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}
variable "project" {
  type    = string
  default = "sub_jh"
}
variable "env" {
  type    = string
  default = "dev"
}
data "aws_availability_zones" "available" {}

#########################
# Networking: VPC & Subnets
#########################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  # → VPC Flow Logs 비활성화 (기본값으로 비활성)  :contentReference[oaicite:0]{index=0}
  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # → 퍼블릭 서브넷에 퍼블릭 IP 자동 할당  :contentReference[oaicite:1]{index=1}
  tags = {
    Name = "${var.project}-${var.env}-public-${count.index + 1}"
  }
}

resource "aws_security_group" "endpoints" {
  name        = "${var.project}-${var.env}-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # → 모든 트래픽 허용 (0.0.0.0/0)  :contentReference[oaicite:3]{index=3}
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.env}-endpoints-sg" }
}

#########################
# SSM Parameter Store
#########################
resource "aws_kms_key" "ssm" {
  description             = "KMS key for SSM SecureString"
  deletion_window_in_days = 7
  enable_key_rotation     = false # → KMS 키 자동 회전 비활성화  :contentReference[oaicite:4]{index=4}

  # → 와일드카드(*) principal 허용
  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"AllowAll",
      "Effect":"Allow",
      "Principal":{"AWS":"*"},
      "Action":"kms:*",
      "Resource":"*"
    }
  ]
}
POLICY
}

resource "aws_ssm_parameter" "common_config" {
  name  = "/${var.project}/${var.env}/config"
  type  = "String" # → SecureString → String으로 변경 (암호화 비활성)  :contentReference[oaicite:5]{index=5}
  value = jsonencode({ timeout = 30, retries = 3 })
  # key_id 삭제 (암호화 해제)
}

#########################
# Lambda Function
#########################
resource "aws_lambda_function" "matchmaker" {
  function_name = "${var.project}-${var.env}-matchmaker"
  handler       = "matchmaker.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "./matchmaker.zip"

  # → VPC 설정 없음 (퍼블릭 인터넷 노출)  :contentReference[oaicite:6]{index=6}

  environment {
    variables = {
      EVENT_BUS    = aws_cloudwatch_event_bus.gamebus.name
      CONFIG_PARAM = aws_ssm_parameter.common_config.name
    }
  }
}

resource "aws_cloudwatch_event_bus" "gamebus" {
  name = "${var.project}-${var.env}-bus"
}

resource "aws_cloudwatch_event_rule" "match_completed" {
  name           = "MatchCompleted"
  event_bus_name = aws_cloudwatch_event_bus.gamebus.name
  event_pattern  = jsonencode({ source = ["game.match"] })
}

resource "aws_cloudwatch_event_target" "to_sfn" {
  rule           = aws_cloudwatch_event_rule.match_completed.name
  event_bus_name = aws_cloudwatch_event_bus.gamebus.name
  arn            = aws_sfn_state_machine.workflow.arn
  role_arn       = aws_iam_role.sfn_exec.arn
}

#########################
# SQS Queues
#########################
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project}-${var.env}-dlq.fifo"
  fifo_queue                = true
  message_retention_seconds = 1209600
  # → 서버사이드 암호화 미사용  :contentReference[oaicite:7]{index=7}
}

resource "aws_sqs_queue" "main" {
  name                        = "${var.project}-${var.env}-main.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
  # → 서버사이드 암호화 미사용 (기본 빼면 비활성)  :contentReference[oaicite:8]{index=8}
}

#########################
# DynamoDB
#########################
resource "aws_dynamodb_table" "player_stats" {
  name         = "${var.project}-${var.env}-playerstats"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "playerId"

  attribute {
    name = "playerId"
    type = "S"
  }
  attribute {
    name = "score"
    type = "N"
  }

  global_secondary_index {
    name            = "ScoreIndex"
    hash_key        = "score"
    projection_type = "ALL"
  }

  server_side_encryption { # → 암호화 비활성화
    enabled = false
  }
}

#########################
# CloudWatch Alarm
#########################
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "MatchmakingLatencyHigh"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  threshold           = 2000
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    FunctionName = aws_lambda_function.matchmaker.function_name
  }
  # → 알람 관련 리소스는 설정했으나, 알림 액션 (SNS 구독 등) 미설정으로 무용지물
}

#########################
# VPC Endpoints
#########################
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.endpoints.id]
  # → Endpoint에 퍼블릭 인터넷 경로 추가 불가 (Interface 타입이지만, 보안 그룹이 0.0.0.0/0 허용 상태)
}

resource "aws_vpc_endpoint" "eventbridge" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${var.aws_region}.events"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.endpoints.id]
}

#########################
# Cognito
#########################
resource "aws_cognito_user_pool" "users" {
  name                     = "${var.project}-${var.env}-users"
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "app" {
  name                = "${var.project}-${var.env}-client"
  user_pool_id        = aws_cognito_user_pool.users.id

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

#########################
# API Gateway REST API 및 자원
#########################
resource "aws_api_gateway_rest_api" "rest" {
  name = "${var.project}-${var.env}-rest"
}

resource "aws_api_gateway_resource" "match" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_rest_api.rest.root_resource_id
  path_part   = "matchmake"
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito-auth"
  rest_api_id     = aws_api_gateway_rest_api.rest.id
  identity_source = "method.request.header.Authorization"
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.users.arn]
}

resource "aws_api_gateway_method" "match_post" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.match.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "match_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest.id
  resource_id             = aws_api_gateway_resource.match.id
  http_method             = aws_api_gateway_method.match_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.matchmaker.invoke_arn
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.matchmaker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest.execution_arn}/*/POST${aws_api_gateway_resource.match.path}"
}

resource "aws_api_gateway_deployment" "rest_dep" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  triggers    = { redeployment = timestamp() }
  depends_on = [
    aws_api_gateway_integration.match_integration,
    aws_lambda_permission.allow_apigw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "rest_stage" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  deployment_id = aws_api_gateway_deployment.rest_dep.id
  stage_name    = var.env
}

#########################
# WAFv2 & Associations
#########################
resource "aws_wafv2_web_acl" "api_acl" {
  name  = "${var.project}-${var.env}-api-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # → RateLimit 룰은 남아있으나, priority 1 외에는 룰 미설정 (탐지 정책 부재)
  rule {
    name     = "RateLimit"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      sampled_requests_enabled   = false # → CloudWatch 메트릭 비활성화
      cloudwatch_metrics_enabled = false
      metric_name                = "rateLimit"
    }
  }

  visibility_config {
    sampled_requests_enabled   = false
    cloudwatch_metrics_enabled = false
    metric_name                = "apiAcl"
  }
}

resource "aws_wafv2_web_acl_association" "rest_assoc" {
  resource_arn = aws_api_gateway_stage.rest_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.api_acl.arn
}

#########################
# IAM Roles
#########################
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-${var.env}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sfn_exec" {
  name               = "${var.project}-${var.env}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

resource "aws_iam_role_policy" "sfn_policy" {
  role = aws_iam_role.sfn_exec.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = "*" }]
  })
}

#########################
# Step Functions (State Machine)
#########################
resource "aws_sfn_state_machine" "workflow" {
  name     = "${var.project}-${var.env}-workflow"
  role_arn = aws_iam_role.sfn_exec.arn

  definition = jsonencode({
    Comment = "Reward workflow"
    StartAt = "DistributeReward"
    States = {
      DistributeReward = {
        Type     = "Task"
        Resource = aws_lambda_function.matchmaker.arn
        Next     = "UpdateStats"
      }
      UpdateStats = {
        Type     = "Task"
        Resource = aws_lambda_function.matchmaker.arn
        Next     = "RecomputeLeaderboard"
      }
      RecomputeLeaderboard = {
        Type     = "Task"
        Resource = aws_lambda_function.matchmaker.arn
        End      = true
      }
    }
  })
}
