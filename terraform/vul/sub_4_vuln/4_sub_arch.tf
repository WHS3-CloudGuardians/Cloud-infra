############################################
# 기본 Provider 설정
############################################
provider "aws" {
  region = "ap-northeast-2"  
  profile = "aws_ym"
}

############################################
# VPC 및 기본 네트워크 구성
############################################
data "aws_vpc" "default" {
  default = true  
}

# 기본 VPC의 Main Route Table 조회
data "aws_route_table" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "igw" {
  vpc_id = data.aws_vpc.default.id
}

# 인터넷 접근 경로 설정 (0.0.0.0/0)
resource "aws_route" "public_internet_access" {
  count = contains(
    data.aws_route_table.default.routes[*].cidr_block,
    "0.0.0.0/0"
  ) ? 0 : 1

  route_table_id         = data.aws_route_table.default.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# 기본 VPC의 모든 서브넷 조회
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################
# Redshift용 Subnet Group 및 보안그룹
############################################

# Redshift 클러스터를 위한 서브넷 그룹
resource "aws_redshift_subnet_group" "default" {
  name        = "default-redshift-subnet-group"
  subnet_ids  = data.aws_subnets.default.ids
  description = "Subnet group for Redshift in default VPC"
}

# Redshift 보안그룹 (전체 공개: 비추천)
resource "aws_security_group" "redshift_sg" {
  name        = "redshift-open-sg"
  description = "Open SG for Redshift (insecure)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 어디서든 접속 허용 (취약)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# IAM Role: Glue & CodeBuild
############################################

# Glue 서비스용 Role (관리자 권한)
resource "aws_iam_role" "glue_admin_role" {
  name = "Admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "glue.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Glue Full Access 정책 연결
resource "aws_iam_policy_attachment" "glue_attach" {
  name       = "attach-glue-admin"
  roles      = [aws_iam_role.glue_admin_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

# CodeBuild 서비스용 Role (관리자 권한)
resource "aws_iam_role" "codebuild_admin_role" {
  name = "CodeBuildAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# CodeBuild에 AdministratorAccess 권한 부여
resource "aws_iam_policy_attachment" "codebuild_attach" {
  name       = "attach-codebuild-admin"
  roles      = [aws_iam_role.codebuild_admin_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################################
# ECR Repository (스캔 비활성화)
############################################

resource "aws_ecr_repository" "example" {
  name = "public-ecr-repo"
  image_scanning_configuration {
    scan_on_push = false  # 보안 취약점 스캔 비활성화 (취약 설정)
  }
}

############################################
# Redshift 클러스터 (공개 노출 + 약한 비밀번호)
############################################

resource "aws_redshift_cluster" "example" {
  cluster_identifier        = "insecure-cluster"
  node_type                 = "ra3.xlplus"
  master_username           = "admin"
  master_password           = "weakPassword123!"  # 약한 비밀번호
  cluster_type              = "single-node"
  publicly_accessible       = true  # 인터넷 공개 (취약)
  skip_final_snapshot       = true  # 종료 시 백업 안함

  cluster_subnet_group_name = aws_redshift_subnet_group.default.name
  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]
}

############################################
# Athena 결과 저장용 S3 버킷 (퍼블릭)
############################################

resource "aws_s3_bucket" "athena_results" {
  bucket        = "wendy-athena-results-20250709"
  force_destroy = true
}

# 퍼블릭 액세스를 허용하는 설정
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

# 버킷에 모든 사용자에게 읽기 허용
resource "aws_s3_bucket_policy" "athena_results_policy" {
  bucket = aws_s3_bucket.athena_results.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.athena_results.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.athena_results]
}

############################################
# Athena 데이터베이스 및 워크그룹
############################################

resource "aws_athena_database" "example" {
  name   = "example_db"
  bucket = aws_s3_bucket.athena_results.bucket
}

resource "aws_athena_workgroup" "example" {
  name = "example-workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }
}

############################################
# AWS SecurityHub 활성화
############################################

resource "aws_securityhub_account" "example" {}

############################################
# Backup Vault (외부 KMS 사용)
############################################

resource "aws_backup_vault" "example" {
  name        = "backup-vault-unencrypted"
  kms_key_arn = "arn:aws:kms:ap-northeast-2:311278774159:key/78823c72-f1c4-4cda-9d74-2d57fff312b4"
}

############################################
# Glue Catalog Database
############################################

resource "aws_glue_catalog_database" "example" {
  name = "example_glue_db"
}

############################################
# Glue Job (공용 스크립트, 관리자 권한)
############################################

resource "aws_glue_job" "example" {
  name     = "glue-job-insecure"
  role_arn = aws_iam_role.glue_admin_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://open-bucket/scripts/script.py"  # 공개 버킷 사용
    python_version  = "3"
  }
}

############################################
# CodeBuild Project (Privileged Mode + 관리자 권한)
############################################

resource "aws_codebuild_project" "example" {
  name         = "codebuild-insecure"
  description  = "CodeBuild with elevated perms"
  service_role = aws_iam_role.codebuild_admin_role.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true  # 루트 권한 가능 (취약)
  }
  source {
    type      = "GITHUB"
    location  = "https://github.com/randomuser/public-repo"
    buildspec = "buildspec.yml"
  }
}

############################################
# SSM 파라미터 (평문 저장)
############################################

resource "aws_ssm_parameter" "example" {
  name  = "/prod/password"
  type  = "String"  # 평문 저장 (취약)
  value = "supersecret123"
}

############################################
# SSM Document (위험한 명령 포함)
############################################

resource "aws_ssm_document" "example" {
  name          = "DangerousCommand"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Root shell script",
    mainSteps = [{
      action = "aws:runShellScript",
      name   = "runRootCommand",
      inputs = {
        runCommand = ["rm -rf /"]  # 위험한 명령 (루트 디렉토리 삭제)
      }
    }]
  })
}
