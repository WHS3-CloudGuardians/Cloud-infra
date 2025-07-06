# backend.tf
terraform {
  required_version = ">= 1.0"
  backend "s3" {
    bucket       = "sub-jh-bucket"
    key          = "sub_jh/dev/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
  }
}
