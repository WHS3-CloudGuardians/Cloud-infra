provider "aws" {
  region = "ap-northeast-2"
}

resource "random_id" "suffix" {
  byte_length = 4
}

################################################################################
# 1) VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name                 = "vuln-vpc"
  cidr                 = "10.10.0.0/16"
  azs                  = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets       = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets      = ["10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway   = true

  tags = {
    Environment = "vuln"
  }
}

################################################################################
# 2) S3 (비암호화, 퍼블릭 정책 허용)
################################################################################

resource "aws_s3_bucket" "event_bucket" {
  bucket        = "vuln-event-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Environment = "vuln"
  }
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket = aws_s3_bucket.event_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# resource "aws_s3_bucket_policy" "allow_public" {
#   bucket = aws_s3_bucket.event_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "PublicRead",
#         Effect    = "Allow",
#         Principal = "*",
#         Action    = "s3:GetObject",
#         Resource  = "${aws_s3_bucket.event_bucket.arn}/*"
#       }
#     ]
#   })
# }

################################################################################
# 3) Security Groups
################################################################################

resource "aws_security_group" "msk_sg" {
  name   = "vuln-msk-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 전체 오픈
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lambda_sg" {
  name   = "vuln-lambda-sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# 4) MSK Cluster
################################################################################

resource "aws_msk_cluster" "this" {
  cluster_name           = "vuln-msk-cluster"
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
    Environment = "vuln"
  }
}

################################################################################
# 5) IAM Role (과도한 권한 포함)
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

resource "aws_iam_role" "lambda_role" {
  name               = "vuln-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["ec2:*", "kafka:*", "s3:*", "logs:*"]
    resources = ["*"] # 모든 리소스에 대한 전체 권한
  }
}

resource "aws_iam_role_policy" "lambda_policy_attach" {
  name   = "vuln-lambda-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

################################################################################
# 6) Lambda Function
################################################################################

resource "aws_lambda_function" "msk_consumer" {
  function_name    = "vuln-msk-consumer"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  handler          = "handler.main"
  filename         = "consumer.zip"
  source_code_hash = filebase64sha256("consumer.zip")

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      TOPIC_NAME = "vuln-topic"
      S3_BUCKET  = aws_s3_bucket.event_bucket.bucket
    }
  }
}

################################################################################
# 7) Lambda Event Source Mapping (MSK → Lambda)
################################################################################

resource "aws_lambda_event_source_mapping" "lambda_msk" {
  event_source_arn  = aws_msk_cluster.this.arn
  function_name     = aws_lambda_function.msk_consumer.arn
  starting_position = "LATEST"
  topics            = ["vuln-topic"]
}
