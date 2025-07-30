############################################
# 기본 Provider 설정
############################################
provider "aws" {
  region = "ap-northeast-2"
}

############################################
# VPC 및 기본 네트워크 구성 (퍼블릭 접근 차단)
############################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################
# Redshift용 Subnet Group 및 보안그룹
############################################
resource "aws_redshift_subnet_group" "secure" {
  name        = "secure-redshift-subnet-group"
  subnet_ids  = data.aws_subnets.default.ids
  description = "Secure subnet group for Redshift"
}

resource "aws_security_group" "redshift_sg" {
  name        = "redshift-secure-sg"
  description = "Restrictive SG for Redshift"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # 내부 네트워크만 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# IAM Role: Glue (최소 권한)
############################################
resource "aws_iam_role" "glue_role" {
  name = "GlueRestrictedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "glue.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "glue_custom_policy" {
  name        = "GlueLeastPrivilege"
  description = "Glue job 제한 정책"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "glue:GetJob",
        "glue:StartJobRun",
        "glue:GetJobRun",
        "glue:GetTable",
        "glue:GetDatabase",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_custom_policy.arn
}

############################################
# IAM Role: CodeBuild (최소 권한)
############################################
resource "aws_iam_role" "codebuild_role" {
  name = "CodeBuildRestrictedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

############################################
# ECR Repository (보안 스캔 활성화)
############################################
resource "aws_ecr_repository" "example" {
  name = "secure-ecr-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
}

############################################
# Redshift 클러스터 (비공개, 강한 비밀번호)
############################################
resource "random_password" "redshift_password" {
  length  = 20
  special = true
}

resource "aws_redshift_cluster" "secure" {
  cluster_identifier        = "secure-cluster"
  node_type                 = "ra3.xlplus"
  master_username           = "secureadmin"
  master_password           = random_password.redshift_password.result
  cluster_type              = "single-node"
  publicly_accessible       = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "secure-cluster-snapshot"

  cluster_subnet_group_name = aws_redshift_subnet_group.secure.name
  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]
  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

############################################
# S3 (퍼블릭 차단 + 버전 관리)
############################################
resource "aws_s3_bucket" "athena_results" {
  bucket        = "wendy-athena-secure-results"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

############################################
# Athena
############################################
resource "aws_athena_database" "secure" {
  name   = "secure_db"
  bucket = aws_s3_bucket.athena_results.bucket
}

resource "aws_athena_workgroup" "secure" {
  name = "secure-workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }
}

############################################
# Glue Catalog Database
############################################
resource "aws_glue_catalog_database" "secure" {
  name = "secure_glue_db"
}

############################################
# Glue Job (공용 스크립트 → 사설 경로, 최소 권한)
############################################
resource "aws_glue_job" "secure" {
  name     = "glue-job-secure"
  role_arn = aws_iam_role.glue_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://secure-bucket/scripts/secure-script.py"
    python_version  = "3"
  }
}

############################################
# CodeBuild Project (Privileged Mode OFF)
############################################
resource "aws_codebuild_project" "secure" {
  name         = "codebuild-secure"
  description  = "CodeBuild with least privilege"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

  source {
    type      = "GITHUB"
    location  = "https://github.com/secure-repo/private"
    buildspec = "buildspec.yml"
  }
}

############################################
# SSM 파라미터 (암호화 저장)
############################################
resource "aws_ssm_parameter" "secure_password" {
  name  = "/prod/password"
  type  = "SecureString"
  value = random_password.redshift_password.result
  overwrite = true
}