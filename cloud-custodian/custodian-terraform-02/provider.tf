# terraform\provider.tf

#########################################
# Terraform 설정
#########################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#########################################
# AWS Provider 설정
#########################################

provider "aws" {
  region = var.aws_region

  # 모든 리소스에 공통 태그 자동 부여
  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}
