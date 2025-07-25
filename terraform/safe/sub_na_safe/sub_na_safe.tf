provider "aws" {
  region = "ap-northeast-2"  
}

# AWS 계정 ID를 가져오기
data "aws_caller_identity" "current" {}

# 랜덤 ID 생성 
resource "random_id" "unique_id" {
  byte_length = 8
}

# VPC 설정
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

# 퍼블릭 서브넷을 두 개의 가용 영역에 배치
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

# 프라이빗 서브넷
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "internet-gateway-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  }
}

# 보안 그룹 설정 
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

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Auto Scaling Group 설정 
resource "aws_launch_template" "web_server" {
  name_prefix   = "web-server-config"
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups            = [aws_security_group.web_sg.id]  
  }
}

resource "aws_autoscaling_group" "web_server_asg" {
  desired_capacity    = 3
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]

  launch_template {
    id      = aws_launch_template.web_server.id  # launch_template_id를 id로 설정
    version = "$Latest"  
  }

  tag {
    key                 = "Name"
    value               = "Web Server"
    propagate_at_launch = true
  }
}

# Application Load Balancer 설정 
resource "aws_lb" "web_load_balancer" {
  name               = "web-lb-${random_id.unique_id.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  enable_deletion_protection = false  
}

resource "aws_db_subnet_group" "main" {
  name        = "main-db-subnet-group-${data.aws_caller_identity.current.account_id}"
  subnet_ids  = [aws_subnet.private_subnet.id, aws_subnet.public_subnet_a.id]
  description = "Main DB subnet group"
}

# Cloud DB (RDS Master/Slave 설정)
resource "aws_db_instance" "master_db" {
  identifier        = "master-db-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  engine            = "mysql"
  instance_class    = "db.m5.large"
  allocated_storage = 20
  username          = "admin"
  password          = "password123"
  db_subnet_group_name = aws_db_subnet_group.main.id
  multi_az          = true
  storage_encrypted = true
  backup_retention_period = 7
  skip_final_snapshot   = true 
}

resource "aws_elasticache_cluster" "redis_cache" {
  cluster_id           = "redis-cluster-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  engine               = "redis"
  node_type            = "cache.m5.large"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
}

# CloudWatch Logs 
resource "aws_cloudwatch_log_group" "web_server_logs" {
  name              = "web-server-logs-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  retention_in_days = 30
}

# S3 버킷 Public Access Block 설정 
resource "aws_s3_bucket_public_access_block" "cloudtrail_block" {
  bucket = aws_s3_bucket.cloudtrail_bucket.bucket

  block_public_acls   = false
  ignore_public_acls  = false
  block_public_policy = false  
}

# S3 버킷 생성 (CloudTrail 로그 저장용)
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
    actions   = ["s3:PutObject", "s3:GetBucketAcl"]
    resources = [
      "${aws_s3_bucket.cloudtrail_bucket.arn}",
      "${aws_s3_bucket.cloudtrail_bucket.arn}/*"
    ]

    # Principal을 서비스로 설정
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# CloudTrail 생성
resource "aws_cloudtrail" "example" {
  name                          = "example-cloudtrail-${random_id.unique_id.hex}-${data.aws_caller_identity.current.account_id}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  include_global_service_events = true
  is_multi_region_trail         = false
}

# WAF (웹 애플리케이션 방화벽)
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

# 고객 게이트웨이 설정
resource "aws_customer_gateway" "example" {
  bgp_asn    = 65001
  ip_address = "1.1.1.1"
  type       = "ipsec.1"
}

# VPN 게이트웨이 설정
resource "aws_vpn_gateway" "example" {
  vpc_id         = aws_vpc.main_vpc.id
  amazon_side_asn = 65002
}

# VPN 연결 설정
resource "aws_vpn_connection" "vpn_connection" {
  customer_gateway_id = aws_customer_gateway.example.id
  vpn_gateway_id     = aws_vpn_gateway.example.id
  type               = "ipsec.1"
}

# 보안 알림 (CloudWatch)
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
