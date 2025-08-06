# 취약한 환경실행시 safe-main.tf.txt로 바꾸기
# 또는 전체 주석처리 

resource "random_id" "suffix" {
  byte_length = 4
}
################################################################################
# 1) VPC 모듈
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name               = "${var.env}-vpc"
  cidr               = "10.10.0.0/16"
  azs                = ["${var.region}a", "${var.region}c"]
  public_subnets     = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets    = ["10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway = true

  tags = {
    Environment = var.env
  }
}

################################################################################
# 2) MSK Cluster
################################################################################
resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.env}-msk-cluster"
  kafka_version          = "2.8.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = module.vpc.private_subnets
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  tags = {
    Environment = var.env
  }
}

################################################################################
# 3) IAM Role for Lambda → MSK + S3 접근
################################################################################
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_msk_exec" {
  name               = "${var.env}-lambda-msk-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_msk_access" {
  statement {
    actions = [
      # EC2 for ENI
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeAvailabilityZones",

      # Kafka access
      "kafka:GetBootstrapBrokers",
      "kafka:DescribeCluster",
      "kafka:DescribeTopic",
      "kafka:ListTopics",
      "kafka:DescribeGroup",
      "kafka:ListGroups",
      "kafka:Connect"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.env}-msk-consumer:*"]
  }

  statement {
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.event_bucket.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_msk_policy" {
  name   = "LambdaMSKAccess"
  role   = aws_iam_role.lambda_msk_exec.id
  policy = data.aws_iam_policy_document.lambda_msk_access.json
}

################################################################################
# 4) Lambda Function
################################################################################
resource "aws_lambda_function" "msk_consumer" {
  function_name    = "${var.env}-msk-consumer"
  role             = aws_iam_role.lambda_msk_exec.arn
  runtime          = "python3.9"
  handler          = "handler.main"
  filename         = "consumer/consumer.zip"
  source_code_hash = filebase64sha256("consumer/consumer.zip")

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      TOPIC_NAME = var.kafka_topic
      LOG_LEVEL  = "INFO"
      S3_BUCKET  = aws_s3_bucket.event_bucket.bucket
    }
  }
}

################################################################################
# 5) Event Source Mapping (MSK → Lambda)
################################################################################
resource "aws_lambda_event_source_mapping" "lambda_msk_mapping" {
  event_source_arn  = aws_msk_cluster.this.arn
  function_name     = aws_lambda_function.msk_consumer.arn
  starting_position = "LATEST"
  topics            = [var.kafka_topic]
}

################################################################################
# 6) Security Groups
################################################################################

# 6.1) MSK Broker Security Group
resource "aws_security_group" "msk_sg" {
  name        = "${var.env}-msk-sg"
  description = "Allow Kafka TLS from Lambda"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.env}-msk-sg"
    Environment = var.env
  }
}

# 6.2) Lambda Security Group
resource "aws_security_group" "lambda_sg" {
  name        = "${var.env}-lambda-sg"
  description = "Allow Lambda outbound to MSK"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.env}-lambda-sg"
    Environment = var.env
  }
}

################################################################################
# 7) S3 버킷: Lambda 처리 결과 저장
################################################################################

resource "aws_s3_bucket" "event_bucket" {
  bucket = "${var.env}-event-data-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Environment = var.env
  }
}