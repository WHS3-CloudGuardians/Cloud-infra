variable "region" {
  type        = string
  description = "AWS Region"
  default     = "ap-northeast-2"
}

variable "rds_password" {
  type        = string
  description = "RDS master user password"
  sensitive   = true
}

# Key Pair Name (EC2 Instance)
variable "key_pair_name" {
  type        = string
  description = "The name of an existing AWS Key Pair to use for EC2 instances"
  default     = "zerry_key1"
}

variable "web_ami_id" {
  type        = string
  description = "AMI ID for Web/App EC2 instances"
  default     = "ami-0f3a440bbcff3d043"
}
variable "instance_type" {
  type        = string
  description = "EC2 instance type for web/app"
  default     = "t3.micro"
}

variable "rds_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}
variable "rds_engine_version" {
  type        = string
  description = "MySQL engine version"
  default     = "8.0.41"
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache Redis node type"
  default     = "cache.t3.micro"
}
variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.0"
}

# EFS Throughput mode
variable "efs_throughput_mode" {
  type        = string
  description = "EFS throughput mode"
  default     = "bursting"
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.32.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "safe-vpc-main"
  cidr = "10.0.0.0/16"

  azs = ["ap-northeast-2a", "ap-northeast-2c"]

  public_subnets = [
    "10.0.1.0/24",  # ap-northeast-2a
    "10.0.2.0/24",  # ap-northeast-2c
  ]
  private_subnets = [
    # Web Tier (AZ-a, AZ-c)
    "10.0.11.0/24",  # safe-subnet-web-01 (ap-northeast-2a)
    "10.0.12.0/24",  # safe-subnet-web-02 (ap-northeast-2c)
    # App Tier (AZ-a, AZ-c)
    "10.0.21.0/24",  # safe-subnet-app-01 (ap-northeast-2a)
    "10.0.22.0/24",  # safe-subnet-app-02 (ap-northeast-2c)
    # DB Tier (AZ-a, AZ-c)
    "10.0.31.0/24",  # safe-subnet-db-01 (ap-northeast-2a)
    "10.0.32.0/24",  # safe-subnet-db-02 (ap-northeast-2c)
  ]

  public_subnet_names = [
    "safe-subnet-public-01",
    "safe-subnet-public-02",
  ]
  private_subnet_names = [
    "safe-subnet-web-01", "safe-subnet-web-02",
    "safe-subnet-app-01", "safe-subnet-app-02",
    "safe-subnet-db-01",  "safe-subnet-db-02",
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  igw_tags = {
    Name = "safe-igw-main"
  }
  nat_gateway_tags = {
    Name = "safe-ngw-main"
  }
}

# ---------------- Web Tier / ALB 관련 SG ----------------

resource "aws_security_group" "alb_public_sg" {
  name        = "safe-sg-alb-public"
  description = "Allow HTTP/HTTPS from Internet to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-alb-public"
  }
}

resource "aws_security_group" "alb_internal_sg" {
  name        = "safe-sg-alb-internal"
  description = "Allow traffic from Web ASG to internal ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
    description     = "Allow Web ASG to App ALB"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-alb-internal"
  }
}

# ---------------- Web / App / DB / EFS / Redis ----------------


resource "aws_security_group" "web_sg" {
  name        = "safe-sg-web"
  description = "Allow HTTP from Public ALB"
  vpc_id      = module.vpc.vpc_id

  # ALB에서 오는 HTTP 허용
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public_sg.id]
    description     = "Allow HTTP from Public ALB"
  }

  # Bastion에서 오는 HTTP 허용 (디버깅용)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow HTTP from Bastion Host"
  }

  # Bastion에서 오는 SSH 허용
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow SSH from Bastion Host"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-web"
  }
}


resource "aws_security_group" "app_sg" {
  name        = "safe-sg-app"
  description = "Allow HTTP 8080 from Internal ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal_sg.id]
    description     = "Allow Internal ALB to App EC2"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-app"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "safe-sg-bastion"
  description = "Allow SSH access from my IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["211.253.228.5/32"]
    description = "Allow SSH from my IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "safe-sg-bastion"
  }
}


resource "aws_security_group" "db_sg" {
  name        = "safe-sg-db"
  description = "Allow MySQL access from App Tier"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
    description     = "Allow App EC2 to RDS"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-db"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "safe-sg-efs"
  description = "Allow NFS access from Web and App servers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [
      aws_security_group.web_sg.id,
      aws_security_group.app_sg.id
    ]
    description = "Allow Web/App to EFS"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-efs"
  }
}

resource "aws_security_group" "redis_sg" {
  name        = "safe-sg-redis"
  description = "Allow Redis access from App Tier"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
    description     = "Allow App EC2 to Redis"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "safe-sg-redis"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_attach" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_secretsmanager_secret" "rds_master" {
  name        = "safe-rds-master-password-${data.aws_caller_identity.current.account_id}"
  description = "RDS master user password for safe-rds-db"
  tags = {
    Name = "safe-rds-master-password"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master_version" {
  secret_id     = aws_secretsmanager_secret.rds_master.id
  secret_string = var.rds_password
}

variable "redis_password" {
  description = "Redis 비밀번호 (Secrets Manager용)"
  type        = string
  sensitive   = true
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name = "safe-redis-auth-token-${data.aws_caller_identity.current.account_id}"
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = var.redis_password  # <- 평문 비밀번호
}


# ---------------- EFS(Key 및 File System) ----------------

resource "aws_kms_key" "safe_efs_key" {
  description             = "KMS key for EFS encryption and CloudTrail"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid       = "AllowRootAccount",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid: "AllowCloudTrailEncryption",
        Effect: "Allow",
        Principal: {
          Service: "cloudtrail.amazonaws.com"
        },
        Action: [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource: "*",
        Condition: {
          StringEquals: {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/safe-cloudtrail"
          }
        }
      }
    ]
  })

  tags = {
    Name = "safe-efs-kms-key"
  }
}


resource "aws_efs_file_system" "safe_efs" {
  creation_token = "safe-efs"
  encrypted      = true
  kms_key_id     = aws_kms_key.safe_efs_key.arn
  throughput_mode = var.efs_throughput_mode

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "safe-efs"
  }
}

locals {
  efs_subnets = [
  module.vpc.private_subnets[0],  # safe-subnet-web-01 (AZ-a)
  module.vpc.private_subnets[1],  # safe-subnet-web-02 (AZ-c)
 ]
}

resource "aws_efs_mount_target" "efs_mt" {
  count          = 2
  file_system_id = aws_efs_file_system.safe_efs.id
  subnet_id      = module.vpc.private_subnets[count.index]
  security_groups = [
    aws_security_group.efs_sg.id
  ]
}


# Secrets Manager에서 비밀번호 문자열 가져오기

# Redis Subnet Group
resource "aws_elasticache_subnet_group" "safe_redis_subnet_group" {
  name        = "safe-redis-subnet-group"
  description = "Subnet group for safe Redis"
  subnet_ids = [
    module.vpc.private_subnets[2],  # safe-subnet-app-01
    module.vpc.private_subnets[3],  # safe-subnet-app-02
  ]
  tags = {
    Name = "safe-redis-subnet-group"
  }
}

# Redis Replication Group
resource "aws_elasticache_replication_group" "safe_redis" {
  replication_group_id       = "safe-redis-rg"
  description                = "Safe Redis Replication Group"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type

  num_node_groups            = 1
  replicas_per_node_group    = 1

  automatic_failover_enabled = true
  port                       = 6379

  subnet_group_name          = aws_elasticache_subnet_group.safe_redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  # 비밀번호 문자열 직접 할당 (ARN X)
  auth_token = aws_secretsmanager_secret_version.redis_auth.secret_string

  multi_az_enabled           = true
  snapshot_retention_limit   = 1

  tags = {
    Name = "safe-redis"
  }
}


resource "aws_db_subnet_group" "safe_db_subnet_group" {
  name        = "safe-db-subnet-group-2"
  description = "Subnet group for Safe RDS"
  subnet_ids = [
    module.vpc.private_subnets[4],  # safe-subnet-db-01 (ap-northeast-2a)
    module.vpc.private_subnets[5],  # safe-subnet-db-02 (ap-northeast-2c)
  ]

  tags = {
    Name = "safe-db-subnet-group-2"
  }
}

resource "aws_db_instance" "safe_rds_db" {
  identifier              = "safe-rds-db"
  engine                  = "mysql"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.safe_efs_key.arn  # 예시: 동일 KMS 키 사용 가능
  multi_az                = true
  publicly_accessible     = false
  deletion_protection     = false
  skip_final_snapshot = true
  db_name                 = "safe_database"
  username                = "admin"
  password = aws_secretsmanager_secret_version.rds_master_version.secret_string

  db_subnet_group_name    = aws_db_subnet_group.safe_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]

  backup_retention_period = 0
  backup_window           = "03:00-03:30"
  maintenance_window      = "wed:04:00-wed:04:30"

  enabled_cloudwatch_logs_exports = [
    "audit","error","general","slowquery"
  ]

  monitoring_interval      = 60
  monitoring_role_arn      = aws_iam_role.rds_monitoring_role.arn

  tags = {
    Name = "safe-rds-db"
  }
}

# ---------------- S3: Web Resource ----------------

# S3 버킷 리소스
resource "aws_s3_bucket" "safe_s3_webresource" {
  bucket        = "safe-s3-webresource-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "safe-s3-webresource"
  }
}

# 서버 측 암호화 설정을 별도의 리소스로 이동
resource "aws_s3_bucket_server_side_encryption_configuration" "safe_s3_webresource_encryption" {
  bucket = aws_s3_bucket.safe_s3_webresource.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "safe_s3_webresource_block" {
  bucket = aws_s3_bucket.safe_s3_webresource.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
# 버전 관리 리소스 추가
resource "aws_s3_bucket_versioning" "safe_s3_webresource_versioning" {
  bucket = aws_s3_bucket.safe_s3_webresource.id

  versioning_configuration {
    status = "Enabled"
  }
}


# ---------------- S3: Monitoring (CloudTrail 로그 저장) ----------------

resource "aws_s3_bucket" "safe_s3_monitor" {
  bucket        = "safe-s3-monitor-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "safe-s3-monitor"
  }
}

# S3 Bucket Policy를 별도의 리소스로 분리
resource "aws_s3_bucket_policy" "safe_s3_monitor_policy" {
  bucket = aws_s3_bucket.safe_s3_monitor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.safe_s3_monitor.bucket}"
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.safe_s3_monitor.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
# 서버 측 암호화 설정을 별도의 리소스로 분리
resource "aws_s3_bucket_server_side_encryption_configuration" "safe_s3_monitor_encryption" {
  bucket = aws_s3_bucket.safe_s3_monitor.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "safe_s3_monitor_versioning" {
  bucket = aws_s3_bucket.safe_s3_monitor.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_canonical_user_id" "current" {}

# ---------------- Public ALB (인터넷-퍼블릭 → Web Tier) ----------------

resource "aws_lb" "public_alb" {
  name               = "safe-public-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_public_sg.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "safe-public-alb"
  }
}

# Web Target Group (HTTP 80)
resource "aws_lb_target_group" "web_tg" {
  name        = "tg-web-tier"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = {
    Name = "tg-web-tier"
  }
}


resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ---------------- Internal ALB (Web Tier → App Tier) ----------------

resource "aws_lb" "internal_alb" {
  name               = "safe-internal-alb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb_internal_sg.id]
  subnets            = [
    module.vpc.private_subnets[0],  # safe-subnet-web-01
    module.vpc.private_subnets[1],  # safe-subnet-web-02
  ]

  tags = {
    Name = "safe-internal-alb"
  }
}


resource "aws_lb_target_group" "app_tg" {
  name        = "tg-app-tier"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = {
    Name = "tg-app-tier"
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ---------------- Launch Template: Web Tier ----------------

resource "aws_launch_template" "web_lt" {
  name_prefix   = "safe-lt-web-"
  image_id      = var.web_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups            = [aws_security_group.web_sg.id]
    associate_public_ip_address = false
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

user_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y nginx nfs-common

systemctl enable nginx
systemctl start nginx

mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.safe_efs.id}.efs.${var.region}.amazonaws.com:/ /mnt/efs
echo "${aws_efs_file_system.safe_efs.id}.efs.${var.region}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab

echo "<html><body><h1>Hello from cloudguardian.site</h1></body></html>" > /var/www/html/index.html
EOF
)


  tags = {
    Name = "safe-web-instance"
  }
}

# ---------------- Auto Scaling Group: Web Tier ----------------

resource "aws_autoscaling_group" "web_asg" {
  name                      = "safe-asg-web"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [
    module.vpc.private_subnets[0],  # safe-subnet-web-01
    module.vpc.private_subnets[1],  # safe-subnet-web-02
  ]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.web_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "safe-web-server"
    propagate_at_launch = true
  }
}

# ---------------- Launch Template: App Tier ----------------

resource "aws_launch_template" "app_lt" {

  name_prefix   = "safe-lt-app-"
  image_id      = var.web_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups            = [aws_security_group.app_sg.id]
    associate_public_ip_address = false
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

user_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y python3-pip nfs-common

pip3 install flask

mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.safe_efs.id}.efs.${var.region}.amazonaws.com:/ /mnt/efs
echo "${aws_efs_file_system.safe_efs.id}.efs.${var.region}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab

cat <<EOT > /home/ubuntu/app.py
from flask import Flask
app = Flask(__name__)

@app.route('/health')
def health():
    return "OK", 200

@app.route('/')
def home():
    return "<h1>Hello from App Tier</h1>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOT

nohup python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &
EOF
)




  tags = {
    Name = "safe-app-instance"
  }
}

# ---------------- Auto Scaling Group: App Tier ----------------

resource "aws_autoscaling_group" "app_asg" {
  name                      = "safe-asg-app"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [
    module.vpc.private_subnets[2],  # safe-subnet-app-01
    module.vpc.private_subnets[3],  # safe-subnet-app-02
  ]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "safe-app-server"
    propagate_at_launch = true
  }
}

resource "aws_instance" "bastion" {
  ami                         = var.web_ami_id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion-host"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
  EOF
  )
}
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_public_subnets" {
  description = "List of public subnets"
  value       = module.vpc.public_subnets
}

output "vpc_private_subnets" {
  description = "List of private subnets"
  value       = module.vpc.private_subnets
}

output "public_alb_dns_name" {
  description = "Public ALB DNS"
  value       = aws_lb.public_alb.dns_name
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS"
  value       = aws_lb.internal_alb.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.safe_rds_db.endpoint
}

output "redis_primary_endpoint_address" {
  description = "Primary endpoint of Redis"
  value       = aws_elasticache_replication_group.safe_redis.primary_endpoint_address
}

output "efs_id" {
  description = "EFS FileSystem ID"
  value       = aws_efs_file_system.safe_efs.id
}

output "s3_webresource_bucket" {
  description = "S3 Webresource Bucket Name"
  value       = aws_s3_bucket.safe_s3_webresource.id
}
output "s3_monitor_bucket" {
  description = "S3 Monitor Bucket Name"
  value       = aws_s3_bucket.safe_s3_monitor.id
}
output "sg_web_id" {
  description = "Security Group ID for Web Tier"
  value       = aws_security_group.web_sg.id
}
output "sg_app_id" {
  description = "Security Group ID for App Tier"
  value       = aws_security_group.app_sg.id
}
output "sg_db_id" {
  description = "Security Group ID for DB"
  value       = aws_security_group.db_sg.id
}
output "sg_efs_id" {
  description = "Security Group ID for EFS"
  value       = aws_security_group.efs_sg.id
}
output "sg_redis_id" {
  description = "Security Group ID for Redis"
  value       = aws_security_group.redis_sg.id
}

output "cloudtrail_log_group_arn" {
  description = "CloudTrail Log Group ARN (for verification)"
  value       = aws_cloudwatch_log_group.cloudtrail_log_group.arn
}


# CloudFront Logging에 사용하는 전체 리전 (버지니아)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

# ------------------------------ AWS CloudFront ------------------------------ 
# ------- S3 bucket For CloudFront Logging ------- 
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket        = "safe-cloudfront-logs-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "safe-cloudfront-logs-bucket"
  }
}
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs_bucket_ownership" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  depends_on = [aws_s3_bucket.cloudfront_logs]
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs_encryption" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
# CloudFront가 로그 업로드할 수 있도록 버킷 정책 추가
resource "aws_s3_bucket_policy" "cloudfront_logs_policy" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudfront_logs.id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# ------- CloudFront 배포 ------- 
resource "aws_cloudfront_distribution" "safe_cloudfront_alb" {
  enabled             = true
  default_root_object = "index.html"

  # 오리진: 퍼블릭 ALB의 DNS 이름
  origin {
    domain_name = aws_lb.public_alb.dns_name
    origin_id   = "public-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "public-alb-origin"

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["www.cloudguardian.site"]

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudguardian_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    bucket = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    include_cookies = false
    prefix          = "logs/"
  }

  tags = {
    Name = "safe-cloudfront-alb"
  }

  depends_on = [
    aws_lb.public_alb,
    aws_acm_certificate_validation.cert
  ]
}


# ------------------------------ AWS WAF ------------------------------ 
# ------- WAF For ALB ------- 
# waf-alb 생성
resource "aws_wafv2_web_acl" "safe_waf_alb" {
  name        = "safe-waf-alb"
  scope       = "REGIONAL"  # ALB는 regional scope
  description = "safe waf for alb"
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "safe-waf-alb-app"
    sampled_requests_enabled   = true
  }
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 0
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    override_action {
      none {}
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
    }
  }
}
# waf-alb 연결
resource "aws_wafv2_web_acl_association" "safe_waf_public_alb_association" {
  resource_arn = aws_lb.public_alb.arn # ALB 생성 후 ARN을 자동 참조
  web_acl_arn  = aws_wafv2_web_acl.safe_waf_alb.arn  # WAF ACL ARN 자동 참조
}

# waf로깅 : cloudwatch-log-group 생성
resource "aws_cloudwatch_log_group" "aws_waf_logs_safe_alb" {
  name = "aws-waf-logs-safe-alb"
}
# waf로깅 : cloudwatch-waf 연결
resource "aws_wafv2_web_acl_logging_configuration" "safe_waf_alb_logging" {
  log_destination_configs = [
    aws_cloudwatch_log_group.aws_waf_logs_safe_alb.arn
  ]
  resource_arn = aws_wafv2_web_acl.safe_waf_alb.arn
}

# ------- WAF For CloudFront ------- 
resource "aws_wafv2_web_acl" "safe_waf_cf" {
  provider = aws.use1
  name        = "safe-waf-cf-${data.aws_caller_identity.current.account_id}"
  scope       = "CLOUDFRONT"  # ALB는 regional scope
  description = "safe waf for cloudfront"
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "safe-waf-cf-app"
    sampled_requests_enabled   = true
  }
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 0

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    override_action {
      none {}
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
    }
  }
}

# waf로깅 : S3 버킷 생성
resource "aws_s3_bucket" "aws_waf_logs_safe_cf" {
  provider = aws.use1
  bucket = "aws-waf-logs-safe-cf-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "aws_waf_logs_safe_cf" {
  provider = aws.use1
  bucket = aws_s3_bucket.aws_waf_logs_safe_cf.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_policy" "aws_waf_logs_policy" {
  provider = aws.use1
  bucket = aws_s3_bucket.aws_waf_logs_safe_cf.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSWAFLogsPolicy"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.aws_waf_logs_safe_cf.id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
# waf로깅 : waf-S3 연결
resource "aws_wafv2_web_acl_logging_configuration" "safe_waf_cf_logging" {
  provider = aws.use1
  log_destination_configs = [
    aws_s3_bucket.aws_waf_logs_safe_cf.arn
  ]
  resource_arn = aws_wafv2_web_acl.safe_waf_cf.arn
}

# SNS Topic + Subscription (for alerts)
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "echan121782@gmail.com"
}

# CloudWatch Log Group (for CloudTrail logs)
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/safe"
  retention_in_days = 90
}

# IAM Role for CloudTrail to write to CloudWatch (with custom inline policy)
resource "aws_iam_role" "cloudtrail_to_cw" {
  name = "cloudtrail-to-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "cloudtrail_to_cw_policy" {
  name = "CloudTrailToCWCustomPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups"
        ],
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "cloudtrail_custom_policy_attach" {
  role       = aws_iam_role.cloudtrail_to_cw.name
  policy_arn = aws_iam_policy.cloudtrail_to_cw_policy.arn
}



# CloudTrail 설정
resource "aws_cloudtrail" "main" {
  name                          = "safe-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.safe_s3_monitor.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cw.arn
  kms_key_id                    = aws_kms_key.safe_efs_key.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name = "safe-cloudtrail"
  }
  depends_on = [
    aws_cloudwatch_log_group.cloudtrail_log_group,
    aws_iam_role.cloudtrail_to_cw,
    aws_iam_role_policy_attachment.cloudtrail_custom_policy_attach
  ]
}

resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "RootAccountUsage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group.name
  pattern        = "{ ($.userIdentity.type = \"Root\") && ($.eventName = \"ConsoleLogin\") }"

  metric_transformation {
    name      = "RootAccountLoginCount"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_login_alarm" {
  alarm_name          = "RootAccountLogin"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.root_login.metric_transformation[0].name
  namespace           = "Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Root account used to log in"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}



# ---------------- SNS -------------------------
resource "aws_s3_bucket" "config_logs" {
  bucket = "safe-config-logs-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "safe-config-logs-bucket"
  }
}
resource "aws_s3_bucket_policy" "config_logs_policy" {
  bucket = aws_s3_bucket.config_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AWSConfigBucketPermissionsCheck",
        Effect: "Allow",
        Principal: {
          Service: "config.amazonaws.com"
        },
        Action: "s3:GetBucketAcl",
        Resource: "arn:aws:s3:::${aws_s3_bucket.config_logs.id}"
      },
      {
        Sid: "AWSConfigBucketDelivery",
        Effect: "Allow",
        Principal: {
          Service: "config.amazonaws.com"
        },
        Action: "s3:PutObject",
        Resource: "arn:aws:s3:::${aws_s3_bucket.config_logs.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition: {
          StringEquals: {
            "s3:x-amz-acl": "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "config.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket
  sns_topic_arn  = aws_sns_topic.security_alerts.arn

  depends_on = [
    aws_config_configuration_recorder.main
  ]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.main
  ]
}

resource "aws_config_config_rule" "ec2_no_public_ip" {
  name = "ec2-instance-no-public-ip"
  source {
    owner             = "AWS"
    source_identifier = "EC2_INSTANCE_NO_PUBLIC_IP"
  }

  depends_on = [
    aws_config_configuration_recorder_status.main
  ]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "cloudtrail-enabled"
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.main
  ]
}

resource "aws_config_config_rule" "root_account_mfa_enabled" {
  name = "root-account-mfa-enabled"
  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.main
  ]
}


resource "aws_cloudwatch_log_metric_filter" "s3_public_upload" {
  name           = "S3PublicUpload"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group.name
  pattern        = "{ ($.eventName = \"PutObject\") && ($.requestParameters.x-amz-acl = \"public-read\") }"

  metric_transformation {
    name      = "S3PublicUploadCount"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_public_upload_alarm" {
  alarm_name          = "S3PublicObjectUploaded"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "S3PublicUploadCount"
  namespace           = "Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# EC2 CPU 사용률 80% 초과 감지 (CloudWatch + SNS)
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "EC2HighCPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 인스턴스의 CPU 사용률이 80%를 초과했습니다."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

# S3 퍼블릭 객체 업로드 감지 (CloudTrail + EventBridge)
resource "aws_cloudwatch_event_rule" "s3_public_object_upload" {
  name        = "S3PublicObjectUploadRule"
  description = "Detect S3 object uploads with public-read/write ACL"
  event_pattern = jsonencode({
    source = ["aws.s3"],
    detail = {
      eventName = ["PutObject", "PutObjectAcl"]
    }
  })
}

resource "aws_cloudwatch_event_target" "s3_public_object_upload_target" {
  rule      = aws_cloudwatch_event_rule.s3_public_object_upload.name
  arn       = aws_sns_topic.security_alerts.arn
}

# 보안 그룹 변경 감지 (CloudTrail + EventBridge)
resource "aws_cloudwatch_event_rule" "security_group_change" {
  name        = "SecurityGroupChangeRule"
  description = "감사: 보안 그룹 생성/수정/삭제 이벤트 감지"
  event_pattern = jsonencode({
    source = ["aws.ec2"],
    detail = {
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress",
        "CreateSecurityGroup",
        "DeleteSecurityGroup"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "security_group_change_target" {
  rule = aws_cloudwatch_event_rule.security_group_change.name
  arn  = aws_sns_topic.security_alerts.arn
}

# WAF 차단 트래픽 증가 감지 (CloudWatch Metric Alarm)
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "WAFBlockedRequestsHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  statistic           = "Sum"
  threshold           = 50
  period              = 300
  alarm_description   = "WAF에서 차단된 요청 수가 5분 동안 50건 이상 발생"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    WebACL = aws_wafv2_web_acl.safe_waf_alb.name
    Region = "ap-northeast-2"
    Rule   = "ALL"
  }
}

# Hosted Zone 데이터
# (이미 사용 중일 수 있으니 확인 후 중복되지 않게)
data "aws_route53_zone" "cloudguardian" {
  name         = "cloudguardian.site"
  private_zone = false
}

# ACM 인증서 (CloudFront는 us-east-1에서만 가능)
resource "aws_acm_certificate" "cloudguardian_cert" {
  provider          = aws.use1
  domain_name       = "www.cloudguardian.site"
  validation_method = "DNS"

  tags = {
    Name = "cloudguardian-site-cert"
  }
}

# DNS 검증 레코드 생성
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudguardian_cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.cloudguardian.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

# 인증서 검증 완료
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cloudguardian_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# Route53 A 레코드: 도메인 → CloudFront
resource "aws_route53_record" "www_alias_to_cloudfront" {
  zone_id = data.aws_route53_zone.cloudguardian.zone_id
  name    = "www.cloudguardian.site"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.safe_cloudfront_alb.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront 고정 Hosted Zone ID
    evaluate_target_health = false
  }
}

resource "aws_backup_vault" "main" {
  name        = "safe-backup-vault"
  kms_key_arn = aws_kms_key.safe_efs_key.arn

  tags = {
    Name = "safe-backup-vault"
  }
}

resource "aws_backup_plan" "main" {
  name = "safe-backup-plan"

  rule {
    rule_name         = "daily-rds-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)" # 매일 오전 5시 (UTC)
    start_window      = 60
    completion_window = 120
    lifecycle {
      delete_after = 7
    }
    recovery_point_tags = {
      Type = "RDS-Daily"
    }
  }

  rule {
    rule_name         = "biweekly-ec2-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * 1,3 *)" # 격주 월/수
    start_window      = 60
    completion_window = 120
    lifecycle {
      delete_after = 30
    }
    recovery_point_tags = {
      Type = "EC2-Biweekly"
    }
  }

  rule {
    rule_name         = "weekly-efs-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 4 ? * SUN *)" # 매주 일요일 오전 4시 (UTC)
    start_window      = 60
    completion_window = 180
    lifecycle {
      delete_after = 30
    }
    recovery_point_tags = {
      Type = "EFS-Weekly"
    }
  }
}

resource "aws_backup_selection" "rds" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "rds-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = [aws_db_instance.safe_rds_db.arn]
}

resource "aws_backup_selection" "ec2" {
  name         = "ec2-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Name"
    value = "safe-web-server"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Name"
    value = "safe-app-server"
  }
}


resource "aws_backup_selection" "efs" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "efs-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = [aws_efs_file_system.safe_efs.arn]
}

resource "aws_iam_role" "backup_role" {
  name = "safe-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "backup.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_attach" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# ---------------- AWS Backup: 사용자 업로드 파일(S3), CloudTrail Logs, CloudWatch Logs, Config 기록 백업 설정 ----------------

# CloudTrail Logs와 CloudWatch Logs는 기존 설정으로 S3에 자동 수집되므로 AWS Backup 대상 아님

# 사용자 업로드 파일: safe_s3_webresource → S3 수명주기 정책 적용 필요
resource "aws_s3_bucket_lifecycle_configuration" "safe_s3_webresource_lifecycle" {
  bucket = aws_s3_bucket.safe_s3_webresource.id

  rule {
    id     = "transition-old-versions-to-glacier"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class    = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# CloudTrail 로그 수명주기 정책 (90일 후 Glacier, 1년 후 삭제)
resource "aws_s3_bucket_lifecycle_configuration" "safe_s3_monitor_lifecycle" {
  bucket = aws_s3_bucket.safe_s3_monitor.id

  rule {
    id     = "cloudtrail-log-archive"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Config 기록 수명주기 정책 (1년 이상 보관)
resource "aws_s3_bucket_lifecycle_configuration" "config_logs_lifecycle" {
  bucket = aws_s3_bucket.config_logs.id

  rule {
    id     = "config-log-retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }
  }
}

# 장기보존 콘텐츠 (예: cloudfront_logs) → Deep Archive로 전환
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs_lifecycle" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "long-term-archive"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
