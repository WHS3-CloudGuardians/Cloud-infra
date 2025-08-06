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
  default     = "t2.micro"
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
  default     = "cache.t2.micro"
}

variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "5.0.6"
}

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

  name = "vuln-vpc-main"
  cidr = "10.0.0.0/16"

  azs = ["ap-northeast-2a", "ap-northeast-2c"]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]

  private_subnets = [
    "10.0.11.0/24", "10.0.12.0/24",
    "10.0.21.0/24", "10.0.22.0/24",
    "10.0.31.0/24", "10.0.32.0/24",
  ]

  public_subnet_names = [
    "vuln-subnet-public-01",
    "vuln-subnet-public-02",
  ]

  private_subnet_names = [
    "vuln-subnet-web-01", "vuln-subnet-web-02",
    "vuln-subnet-app-01", "vuln-subnet-app-02",
    "vuln-subnet-db-01",  "vuln-subnet-db-02",
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  igw_tags = {
    Name = "vuln-igw-main"
  }

  nat_gateway_tags = {
    Name = "vuln-ngw-main"
  }
}

resource "aws_security_group" "alb_public_sg" {
  name        = "vuln-sg-alb-public"
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
    Name = "vuln-sg-alb-public"
  }
}

resource "aws_security_group" "alb_internal_sg" {
  name        = "vuln-sg-alb-internal"
  description = "Allow all traffic from Web ASG to App ALB (too open)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all traffic from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vuln-sg-alb-internal"
  }
}

# ---------------- Web / App / DB / EFS / Redis ----------------


# Web 서버용 Security Group
resource "aws_security_group" "web_sg" {
  name        = "vuln-sg-web"
  description = "Allow HTTP/SSH from Public ALB and Bastion"
  vpc_id      = module.vpc.vpc_id

  # HTTP from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public_sg.id]
    description     = "Allow HTTP from Public ALB"
  }

  # HTTP from Bastion (불필요하게 열려 있음)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow HTTP from Bastion Host"
  }

  # SSH from anywhere (취약점 - 전세계에 SSH 오픈)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from Internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vuln-sg-web"
  }
}

# App 서버용 Security Group
resource "aws_security_group" "app_sg" {
  name        = "vuln-sg-app"
  description = "Allow all traffic from ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal_sg.id]
    description     = "Allow Internal ALB to App EC2"
  }

  ingress {
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [aws_security_group.bastion_sg.id]
  description     = "Allow SSH from Bastion Host"
}


  # 다른 포트 접근 제한 없음 (기본 상태 유지)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vuln-sg-app"
  }
}

# Bastion Host SG
resource "aws_security_group" "bastion_sg" {
  name        = "vuln-sg-bastion"
  description = "Allow SSH from anywhere"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 전 세계 오픈 (취약)
    description = "Allow SSH from Internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vuln-sg-bastion"
  }
}

# DB Security Group
resource "aws_security_group" "db_sg" {
  name        = "vuln-sg-db"
  description = "Allow MySQL access from App Tier"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"] # DB 포트 전세계 오픈 (매우 취약)
    description     = "Allow MySQL from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vuln-sg-db"
  }
}

# EFS Security Group
resource "aws_security_group" "efs_sg" {
  name        = "vuln-sg-efs"
  description = "Allow NFS access from Web and App servers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # NFS 포트 전면 오픈 (취약)
    description = "Allow NFS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vuln-sg-efs"
  }
}

# Redis Security Group
resource "aws_security_group" "redis_sg" {
  name        = "vuln-sg-redis"
  description = "Allow Redis access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Redis 포트 전체 오픈 (취약)
    description = "Allow Redis access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vuln-sg-redis"
  }
}


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



# ---------------- EFS(Key 및 File System) ----------------

data "aws_caller_identity" "current" {}

# RDS 비밀번호를 Secrets Manager에 저장하긴 하지만, 이 설정만으로는 KMS를 명시적으로 사용하지 않음 (추후에 연계하지 않음)
resource "aws_secretsmanager_secret" "rds_master" {
  name        = "vuln-rds-master-password-${data.aws_caller_identity.current.account_id}"
  description = "RDS master user password for vuln-rds-db"

  tags = {
    Name = "vuln-rds-master-password"
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

# Redis auth token도 마찬가지로 저장하되, 암호화 키 지정 없이 기본값 사용 (관리 불명확)
resource "aws_secretsmanager_secret" "redis_auth" {
  name = "vuln-redis-auth-token-${data.aws_caller_identity.current.account_id}"
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = var.redis_password
}

# KMS Key 정의는 생략 → EFS 암호화에서 사용 안함
# (취약점: 중요한 저장소에 대해 암호화 없음)

# EFS 파일 시스템: 암호화 비활성화 (기본값 false)
resource "aws_efs_file_system" "vuln_efs" {
  creation_token  = "vuln-efs"
  encrypted       = false # 암호화 비활성화
  throughput_mode = var.efs_throughput_mode

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "vuln-efs"
  }
}

locals {
  efs_subnets = [
    module.vpc.private_subnets[0],
    module.vpc.private_subnets[1],
  ]
}

# EFS 마운트 타겟은 그대로 생성
resource "aws_efs_mount_target" "efs_mt" {
  count           = 2
  file_system_id  = aws_efs_file_system.vuln_efs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}


# Secrets Manager에서 비밀번호 문자열 가져오기

# Redis Subnet Group
resource "aws_elasticache_subnet_group" "vuln_redis_subnet_group" {
  name        = "vuln-redis-subnet-group"
  description = "Subnet group for vuln Redis"
  subnet_ids = [
    module.vpc.private_subnets[2],
    module.vpc.private_subnets[3],
  ]

  tags = {
    Name = "vuln-redis-subnet-group"
  }
}

# Redis Replication Group (암호화 비활성화)
resource "aws_elasticache_replication_group" "vuln_redis" {
  replication_group_id       = "vuln-redis-rg"
  description                = "Vuln Redis Replication Group"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type

  num_node_groups            = 1
  replicas_per_node_group    = 1

  automatic_failover_enabled = false # 고가용성 비활성화
  port                       = 6379

  subnet_group_name          = aws_elasticache_subnet_group.vuln_redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]

  at_rest_encryption_enabled = false # 데이터 저장 시 암호화 비활성화
  transit_encryption_enabled = true

  auth_token = aws_secretsmanager_secret_version.redis_auth.secret_string

  multi_az_enabled           = false
  snapshot_retention_limit   = 0 # 백업 없음

  tags = {
    Name = "vuln-redis"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "vuln_db_subnet_group" {
  name        = "vuln-db-subnet-group"
  description = "Subnet group for Vuln RDS"
  subnet_ids = [
    module.vpc.private_subnets[4],
    module.vpc.private_subnets[5],
  ]

  tags = {
    Name = "vuln-db-subnet-group"
  }
}

# RDS 인스턴스 (암호화 비활성화, 백업 없음, 단일 AZ, 공용 접근 허용)
resource "aws_db_instance" "vuln_rds_db" {
  identifier              = "vuln-rds-db"
  engine                  = "mysql"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  storage_encrypted       = false # 스토리지 암호화 안 함
  publicly_accessible     = true  # 공용 접근 허용
  multi_az                = false # 단일 AZ
  deletion_protection     = false
  skip_final_snapshot = true

  db_name                 = "vulndb"
  username                = "admin"
  password                = aws_secretsmanager_secret_version.rds_master_version.secret_string

  db_subnet_group_name    = aws_db_subnet_group.vuln_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]

  backup_retention_period = 0     # 백업 없음
  backup_window           = "00:00-00:30"
  maintenance_window      = "mon:01:00-mon:01:30"

  monitoring_interval      = 0    # 모니터링 꺼짐
  enabled_cloudwatch_logs_exports = []

  tags = {
    Name = "vuln-rds-db"
  }
}

# ---------------- S3: Web Resource ----------------

# 퍼블릭 접근 가능한 S3 버킷 (웹 리소스용)
resource "aws_s3_bucket" "vuln_s3_webresource" {
  bucket        = "vuln-s3-webresource-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "vuln-s3-webresource"
  }
}

# 버전 관리 비활성화 (생략됨)

# 암호화 미적용
# 서버 측 암호화 리소스 정의 생략됨

# 퍼블릭 접근 차단 설정 비활성화 → 누구나 읽기 가능
resource "aws_s3_bucket_public_access_block" "vuln_s3_webresource_block" {
  bucket = aws_s3_bucket.vuln_s3_webresource.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 정적 파일 업로드를 위한 공개 ACL 예시
# resource "aws_s3_bucket_acl" "vuln_acl" {
#  bucket = aws_s3_bucket.vuln_s3_webresource.id
#  acl    = "public-read"
# }

# ALB (퍼블릭, HTTPS 없음)
resource "aws_lb" "vuln_public_alb" {
  name               = "vuln-public-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_public_sg.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "vuln-public-alb"
  }
}

# ALB Listener (HTTP만 구성)
resource "aws_lb_target_group" "vuln_web_tg" {
  name        = "tg-vuln-web"
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
    Name = "tg-vuln-web"
  }
}

resource "aws_lb_listener" "vuln_public_http" {
  load_balancer_arn = aws_lb.vuln_public_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vuln_web_tg.arn
  }
}

# ---------------- Internal ALB (Web Tier → App Tier) ----------------

resource "aws_lb" "internal_alb" {
  name               = "vuln-internal-alb"
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


resource "aws_lb_target_group" "vuln_app_tg" {
  name        = "tg-vuln-app"
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
    target_group_arn = aws_lb_target_group.vuln_app_tg.arn
  }
}

# ---------------- Launch Template: Web Tier ----------------

# Web Tier Launch Template
resource "aws_launch_template" "vuln_web_lt" {
  name_prefix   = "vuln-lt-web-"
  image_id      = var.web_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups             = [aws_security_group.web_sg.id]
    associate_public_ip_address = true # 퍼블릭 IP 자동 할당 (취약)
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp2"
      encrypted             = false # EBS 암호화 비활성화 (취약)
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = false # 세부 모니터링 비활성화
  }

user_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y nginx nfs-common

systemctl enable nginx
systemctl start nginx

mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.vuln_efs.id}.efs.${var.region}.amazonaws.com:/ /mnt/efs
echo "${aws_efs_file_system.vuln_efs.id}.efs.${var.region}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab

echo "<html><body><h1>Hello from cloudguardian.site</h1></body></html>" > /var/www/html/index.html
EOF
)


  tags = {
    Name = "vuln-web-instance"
  }
}

# Web Tier Auto Scaling Group
resource "aws_autoscaling_group" "vuln_web_asg" {
  name                      = "vuln-asg-web"
  desired_capacity = 2
  min_size         = 2
  max_size         = 4
  vpc_zone_identifier       = module.vpc.public_subnets # 퍼블릭 서브넷에 배치 (외부 노출)

  launch_template {
    id      = aws_launch_template.vuln_web_lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.vuln_web_tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "vuln-web-server"
    propagate_at_launch = true
  }
}

# App Tier Launch Template
resource "aws_launch_template" "vuln_app_lt" {
  name_prefix   = "vuln-lt-app-"
  image_id      = var.web_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups             = [aws_security_group.app_sg.id]
    associate_public_ip_address = true # App Tier도 퍼블릭 IP 사용 (불필요하게 노출)
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp2"
      encrypted             = false # 암호화 안 됨
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = false
  }

user_data = base64encode(<<EOF
#!/bin/bash
apt-get update -y
apt-get install -y python3-pip
pip3 install flask

mkdir -p /home/ubuntu
chown ubuntu:ubuntu /home/ubuntu

cat << 'EOT' > /home/ubuntu/app.py
from flask import Flask
app = Flask(__name__)

@app.route('/health')
def health():
    return "OK", 200

@app.route('/')
def home():
    return "Hello from Vuln App Tier"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOT

nohup python3 /home/ubuntu/app.py > /home/ubuntu/app.log 2>&1 &
EOF
)



  tags = {
    Name = "vuln-app-instance"
  }
}

# App Tier Auto Scaling Group
resource "aws_autoscaling_group" "vuln_app_asg" {
  name                      = "vuln-asg-app"
  desired_capacity = 2
  min_size         = 2
  max_size         = 4
  vpc_zone_identifier       = module.vpc.public_subnets # App도 퍼블릭에 배치 (취약)

  launch_template {
    id      = aws_launch_template.vuln_app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.vuln_app_tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "vuln-app-server"
    propagate_at_launch = true
  }
}


# ---------------- Bastion Host ----------------
resource "aws_instance" "vuln_bastion" {
  ami                         = var.web_ami_id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0] # 퍼블릭 서브넷 배치
  associate_public_ip_address = true                         # 퍼블릭 IP 부여 (보안 취약)
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "vuln-bastion-host"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
  EOF
  )
}

# ---------------- Outputs ----------------

output "bastion_public_ip" {
  description = "Public IP of the Bastion host"
  value       = aws_instance.vuln_bastion.public_ip
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
  value       = aws_lb.vuln_public_alb.dns_name
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS"
  value       = aws_lb.internal_alb.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.vuln_rds_db.endpoint
}

output "redis_primary_endpoint_address" {
  description = "Primary endpoint of Redis"
  value       = aws_elasticache_replication_group.vuln_redis.primary_endpoint_address
}

output "efs_id" {
  description = "EFS FileSystem ID"
  value       = aws_efs_file_system.vuln_efs.id
}

output "s3_webresource_bucket" {
  description = "S3 Webresource Bucket Name"
  value       = aws_s3_bucket.vuln_s3_webresource.id
}

output "s3_monitor_bucket" {
  description = "S3 Monitor Bucket Name"
  value       = aws_s3_bucket.vuln_s3_monitor.id
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



# CloudFront Logging에 사용하는 전체 리전 (버지니아)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

# ------------------------------ Vuln CloudFront ------------------------------ 
# CloudFront용 S3 로그 버킷 없음
# 로그 비활성화, TLS 설정 미흡, WAF 연결 없음

resource "aws_cloudfront_distribution" "vuln_cloudfront_alb" {
  enabled             = true
  default_root_object = "index.html"

  aliases = ["www.cloudguardian.site"]

  # Origin: 퍼블릭 ALB의 DNS 이름 (암호화 없는 HTTP 사용)
  origin {
    domain_name = aws_lb.vuln_public_alb.dns_name
    origin_id   = "vuln-public-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # TLS 사용 안 함 (취약)
      origin_ssl_protocols   = ["TLSv1.1"]   # 매우 낮은 TLS 프로토콜 허용 (취약)
    }
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "vuln-public-alb-origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"  # 모든 쿠키 전달 (불필요하게 과도함)
      }
    }

    viewer_protocol_policy = "allow-all"  # HTTP 허용 (취약)
    min_ttl                = 0
    default_ttl            = 3000           # 매우 짧은 TTL (성능 저하)
    max_ttl                = 50000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 인증서 생략 → CloudFront 기본 인증서 사용 (보안 약함)
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudguardian_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # 로깅 설정 없음 (가시성 부족)
  # logging_config 생략

  tags = {
    Name = "vuln-cloudfront-alb"
  }

  depends_on = [aws_lb.vuln_public_alb]
}



# -------------------- WAF 구성 생략 (전혀 없음) --------------------

# WAF 리소스를 아예 선언하지 않음
# 또는 아래처럼 선언만 하고 아무 룰도 적용하지 않음 (무의미)

resource "aws_wafv2_web_acl" "vuln_waf" {
  name        = "vuln-waf"
  scope       = "REGIONAL"
  description = "Vulnerable WAF without any rules"

  default_action {
    allow {}  # 기본적으로 모든 요청 허용
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "vuln-waf"
    sampled_requests_enabled   = false
  }

  # rule 블록 없음 → 실질적 필터링 X
}

# 연결도 하지 않음 → ALB, CloudFront에서 적용 안 됨
# aws_wafv2_web_acl_association 누락


# ------------------------------ Vuln CloudTrail ------------------------------ 
# CloudTrail 비활성화 또는 불완전 구성
# 로깅 대상 누락, 암호화 미적용, CloudWatch 미연결

# CloudTrail 구성 생략 또는 다음과 같이 불완전하게 구성

resource "aws_cloudtrail" "vuln_trail" {
  name                          = "vuln-trail"
  s3_bucket_name                = aws_s3_bucket.vuln_s3_monitor.bucket                   
  include_global_service_events = false                   # 글로벌 이벤트 로깅 안 함
  is_multi_region_trail         = false                   # 멀티 리전 아님
  enable_log_file_validation    = false                   # 로그 무결성 확인 비활성화
  depends_on = [aws_s3_bucket_policy.vuln_s3_monitor_policy]

  # 로그 파일 암호화 누락
  # CloudWatch Logs 연동 생략
  # SNS 알림 없음
}

# 퍼블릭 접근 차단 안 한 S3 (CloudTrail 로그 저장 버킷임에도 불구하고 취약하게 설정)
resource "aws_s3_bucket" "vuln_s3_monitor" {
  bucket        = "vuln-cloudtrail-monitor-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "vuln-cloudtrail-monitor"
  }
}

# 암호화 미적용 (취약)
# 서버사이드 암호화 생략

# 퍼블릭 접근 차단 비활성화 (취약)
resource "aws_s3_bucket_public_access_block" "vuln_s3_monitor_block" {
  bucket = aws_s3_bucket.vuln_s3_monitor.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# CloudTrail이 로그 쓰기 위한 최소 권한 정책 부여
resource "aws_s3_bucket_policy" "vuln_s3_monitor_policy" {
  bucket = aws_s3_bucket.vuln_s3_monitor.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AWSCloudTrailWrite",
        Effect: "Allow",
        Principal: {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.vuln_s3_monitor.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl": "bucket-owner-full-control"
          }
        }
      },
      {
        Sid: "AWSCloudTrailGetAcl",
        Effect: "Allow",
        Principal: {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${aws_s3_bucket.vuln_s3_monitor.id}"
      }
    ]
  })
}



# ---------------- SNS -------------------------
# 퍼블릭 접근 차단 안 한 S3 버킷 (로그 저장용)
resource "aws_s3_bucket" "vuln_config_logs" {
  bucket        = "vuln-config-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "vuln-config-logs"
  }
}

# 암호화 미적용 (서버 사이드 암호화 없음)

# 퍼블릭 접근 차단 비활성화
resource "aws_s3_bucket_public_access_block" "vuln_config_logs_block" {
  bucket = aws_s3_bucket.vuln_config_logs.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 버킷 정책은 허용하되, CloudTrail처럼 최소 권한 수준 유지
resource "aws_s3_bucket_policy" "vuln_config_logs_policy" {
  bucket = aws_s3_bucket.vuln_config_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AWSConfigBucketPermissionsCheck",
        Effect: "Allow",
        Principal: {
          Service = "config.amazonaws.com"
        },
        Action = "s3:GetBucketAcl",
        Resource = "arn:aws:s3:::${aws_s3_bucket.vuln_config_logs.id}"
      },
      {
        Sid: "AWSConfigBucketDelivery",
        Effect: "Allow",
        Principal: {
          Service = "config.amazonaws.com"
        },
        Action = "s3:PutObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.vuln_config_logs.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition: {
          StringEquals: {
            "s3:x-amz-acl": "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}


# IAM Role은 부여하지만 최소 권한만
resource "aws_iam_role" "vuln_config_role" {
  name = "vuln-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service: "config.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vuln_config_policy_attach" {
  role       = aws_iam_role.vuln_config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Recorder는 생성되지만 실제 Status는 비활성화
resource "aws_config_configuration_recorder" "vuln_main" {
  name     = "vuln-config-recorder"
  role_arn = aws_iam_role.vuln_config_role.arn

  recording_group {
    all_supported = true
  }
}

# Delivery Channel 구성되지만 SNS 미연결
resource "aws_config_delivery_channel" "vuln_main" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.vuln_config_logs.bucket
}

# 실제로는 작동 안 함 (is_enabled = false)
resource "aws_config_configuration_recorder_status" "vuln_status" {
  name       = aws_config_configuration_recorder.vuln_main.name
  is_enabled = false
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
    name                   = aws_cloudfront_distribution.vuln_cloudfront_alb.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront 고정 Hosted Zone ID
    evaluate_target_health = false
  }
}
