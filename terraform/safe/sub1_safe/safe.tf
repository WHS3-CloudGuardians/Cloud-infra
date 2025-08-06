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

# Variables
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

# Networking: VPC & Subnets
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-${var.env}-public-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-${var.env}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-${var.env}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "endpoints" {
  name        = "${var.project}-${var.env}-endpoints-sg"
  description = "SG for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.env}-endpoints-sg" }
}

# Cognito
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

# API Gateway REST & v2 WebSocket
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
  depends_on  = [
    aws_api_gateway_integration.match_integration,
    aws_lambda_permission.allow_apigw
  ]
  lifecycle {
     create_before_destroy = true
   }
}

resource "aws_api_gateway_stage" "rest_stage" {
  rest_api_id    = aws_api_gateway_rest_api.rest.id
  deployment_id  = aws_api_gateway_deployment.rest_dep.id
  stage_name     = var.env
}

resource "aws_apigatewayv2_api" "ws" {
  name                       = "${var.project}-${var.env}-ws"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.ws.id
  route_key = "$default"
}

resource "aws_apigatewayv2_stage" "ws_stage" {
  api_id      = aws_apigatewayv2_api.ws.id
  name        = var.env
  auto_deploy = true
}

# WAFv2 & Associations
resource "aws_wafv2_web_acl" "api_acl" {
  name  = "${var.project}-${var.env}-api-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

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
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "rateLimit"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "apiAcl"
  }
}

resource "aws_wafv2_web_acl_association" "rest_assoc" {
  resource_arn = aws_api_gateway_stage.rest_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.api_acl.arn
}


# IAM Roles
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
  role   = aws_iam_role.sfn_exec.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = "*" }]
  })
}

# SSM Parameter Store
resource "aws_kms_key" "ssm" {
  description             = "KMS key for SSM SecureString"
  deletion_window_in_days = 7
}

resource "aws_ssm_parameter" "common_config" {
  name   = "/${var.project}/${var.env}/config"
  type   = "SecureString"
  value  = jsonencode({ timeout = 30, retries = 3 })
  key_id = aws_kms_key.ssm.arn
}

# Lambda Function
resource "aws_lambda_function" "matchmaker" {
  function_name = "${var.project}-${var.env}-matchmaker"
  handler       = "matchmaker.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "./matchmaker.zip"

  environment {
    variables = {
      EVENT_BUS    = aws_cloudwatch_event_bus.gamebus.name
      CONFIG_PARAM = aws_ssm_parameter.common_config.name
    }
  }
}

# EventBridge (CloudWatch Events)
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

# SQS Queues
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project}-${var.env}-dlq.fifo"
  fifo_queue                = true
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "main" {
  name                        = "${var.project}-${var.env}-main.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}

# Step Functions
resource "aws_sfn_state_machine" "workflow" {
  name     = "${var.project}-${var.env}-workflow"
  role_arn = aws_iam_role.sfn_exec.arn

  definition = jsonencode({
    Comment = "Reward workflow"
    StartAt = "DistributeReward"
    States = {
      DistributeReward    = { Type = "Task", Resource = aws_lambda_function.matchmaker.arn, Next = "UpdateStats" }
      UpdateStats         = { Type = "Task", Resource = aws_lambda_function.matchmaker.arn, Next = "RecomputeLeaderboard" }
      RecomputeLeaderboard= { Type = "Task", Resource = aws_lambda_function.matchmaker.arn, End = true }
    }
  })
}

# DynamoDB
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
}

# SNS
resource "aws_sns_topic" "leaderboard_updates" {
  name = "${var.project}-${var.env}-leaderboard"
}

# CloudWatch Alarm
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
}

# VPC Endpoints
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id
  security_group_ids= [aws_security_group.endpoints.id]
}

resource "aws_vpc_endpoint" "eventbridge" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.events"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id
  security_group_ids= [aws_security_group.endpoints.id]
}
