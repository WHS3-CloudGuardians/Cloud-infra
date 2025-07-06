provider "aws" {
  region = "ap-northeast-2"
}

# AWS 계정 ID를 가져오기
data "aws_caller_identity" "current" {}

# 랜덤 ID 생성
resource "random_id" "unique_id" {
  byte_length = 8
}

# VPC 설정 (퍼블릭 서브넷만 사용)
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

# 퍼블릭 서브넷 설정
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-a-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "internet-gateway-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

# 보안 그룹 설정 (SSH와 RDP 외에도 모든 포트 열기)
resource "aws_security_group" "web_sg" {
  name        = "web-sg-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main_vpc.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  # 모든 포트 열기 (더 취약하게 설정)
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
  }
}

# DB Subnet Group 설정 
resource "aws_db_subnet_group" "main" {
  name        = "main-db-subnet-group-${random_id.unique_id.hex}"
  subnet_ids  = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  description = "Main DB subnet group"
}

# RDS 설정 (퍼블릭 액세스 허용, 암호화하지 않음)
resource "aws_db_instance" "master_db" {
  identifier        = "master-db-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  engine            = "mysql"
  instance_class    = "db.m5.large"
  allocated_storage = 20
  username          = "admin"
  password          = "password123"
  db_subnet_group_name = aws_db_subnet_group.main.id
  multi_az          = true
  storage_encrypted = false  
  backup_retention_period = 7
  skip_final_snapshot   = true
  publicly_accessible = true  
}

# S3 버킷 Public Access Block 설정 
resource "aws_s3_bucket_public_access_block" "cloudtrail_block" {
  bucket = aws_s3_bucket.cloudtrail_bucket.bucket

  block_public_acls   = false
  ignore_public_acls  = false
  block_public_policy = false  
}

# S3 버킷 생성
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "subarch-ym-cloudtrail-logs-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true  
}

# CloudTrail에 로그를 쓸 수 있는 권한을 부여하는 S3 버킷 정책
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.bucket
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

# CloudTrail 정책 문서 생성
data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    actions = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_bucket.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid     = "AWSCloudTrailWrite"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}


# CloudTrail 생성
resource "aws_cloudtrail" "example" {
  name                          = "example-cloudtrail-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
}

# WAF 기본 동작 'allow'로 설정 (모든 요청 허용)
resource "aws_wafv2_web_acl" "web_acl" {
  name        = "web-acl-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  description = "Web ACL for e-commerce"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "web-acl-metric"
    sampled_requests_enabled  = true
  }
}

# 보안 알림 (CPU가 높은 경고)
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "high-cpu-alarm-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = ["arn:aws:sns:ap-northeast-2:123456789012:alarm-actions"]
}
