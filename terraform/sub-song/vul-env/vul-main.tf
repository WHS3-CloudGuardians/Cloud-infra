# 안전한 환경실행시 vul-main.tf.txt로 바꾸기
# 또는 전체 주석처리 

provider "aws" {
  region = "ap-northeast-2" # 서울 리전
}

################################################################################
# 1) S3 Bucket
################################################################################
resource "aws_s3_bucket" "event_bucket" {
  bucket        = "dev-test-event-bucket"
  force_destroy = true

  tags = {
    Name        = "TestBucket"
    Environment = "dev"
  }
}

################################################################################
# 2) IAM Role + Policy (Lambda → S3 접근)
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
  name               = "dev-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:logs:ap-northeast-2:*:log-group:/aws/lambda/dev-consumer:*",
      "${aws_s3_bucket.event_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_policy_attachment" {
  name   = "LambdaS3Policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

################################################################################
# 3) Lambda Function
################################################################################
resource "aws_lambda_function" "consumer" {
  function_name    = "dev-consumer"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  handler          = "handler.main"
  filename         = "consumer.zip"
  source_code_hash = filebase64sha256("consumer.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.event_bucket.bucket
    }
  }
}