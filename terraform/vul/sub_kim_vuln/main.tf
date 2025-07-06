terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

provider "random" {}

data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 1. 기본 VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
   filter {
   name   = "availability-zone"
   values = ["ap-northeast-2a", "ap-northeast-2c"]
 }
}

locals {
  subnet_ids   = data.aws_subnets.default.ids
  subnet_count = length(local.subnet_ids)
}

resource "random_integer" "subnet_idx" {
  count = local.subnet_count > 0 ? 1 : 0
  min   = 0
  max   = local.subnet_count - 1
}

# 2. 보안그룹: 전 포트·전 프로토콜 모두 허용
resource "aws_security_group" "wide_open" {
  name        = "wide-open-sg"
  description = "Allow ALL from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. EC2 인스턴스: 퍼블릭 IP + wide-open SG
resource "aws_instance" "insecure_ec2" {
  count                      = local.subnet_count > 0 ? 1 : 0
  ami                        = data.aws_ami.amazon_linux2.id
  instance_type              = "t2.micro"
  associate_public_ip_address = true

  subnet_id = local.subnet_ids[
    random_integer.subnet_idx[0].result
  ]

  vpc_security_group_ids = [aws_security_group.wide_open.id]
  tags                   = { Name = "insecure-ec2" }
}

# 4. S3 버킷: 퍼블릭 읽기/쓰기, 암호화 없음, 버전 관리 없음, 웹사이트 호스팅
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "public_bucket" {
  bucket = "insecure-public-bucket-${random_id.bucket_suffix.hex}"

  tags = { Environment = "insecure" }
}

# S3 웹사이트 설정 (deprecated 대신 별도 리소스)
resource "aws_s3_bucket_website_configuration" "public_site" {
  bucket = aws_s3_bucket.public_bucket.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# S3 버전 관리 설정 (deprecated 대신 별도 리소스)
resource "aws_s3_bucket_versioning" "public_versioning" {
  bucket = aws_s3_bucket.public_bucket.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_account_public_access_block" "allow_public_acls" {
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.public_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = "*",
      Action    = ["s3:GetObject","s3:PutObject"],
      Resource  = "${aws_s3_bucket.public_bucket.arn}/*"
    }]
  })
  depends_on = [
    aws_s3_bucket_public_access_block.allow_bucket_policy
  ]
}

resource "aws_s3_account_public_access_block" "allow_public_policy" {
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "allow_bucket_policy" {
  bucket                  = aws_s3_bucket.public_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 5. IAM 사용자: 루트 유사 Admin 권한, MFA 없음
resource "aws_iam_user" "admin_user" {
  name = "insecure-admin"
}

resource "aws_iam_user_policy_attachment" "admin_attach" {
  user       = aws_iam_user.admin_user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 6. CloudTrail: 완전 비활성화 (정의 없음)

# 7. 출력
output "ec2_public_ip" {
  value = aws_instance.insecure_ec2[0].public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.public_bucket.bucket
}

output "iam_admin" {
  value = aws_iam_user.admin_user.name
}

