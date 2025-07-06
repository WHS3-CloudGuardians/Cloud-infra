//AWS 프로바이더 설정 및 백엔드(원한다면 S3) 설정.

terraform {
  required_version = ">= 1.1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

#   backend "s3" {              # 원격 상태 저장소를 쓰려면 주석 해제
#     # bucket = "my-terraform-state"
#     # key    = "msk-lambda/terraform.tfstate"
#     # region = "ap-northeast-2"
#   }
}

provider "aws" {
  region = var.region
}
