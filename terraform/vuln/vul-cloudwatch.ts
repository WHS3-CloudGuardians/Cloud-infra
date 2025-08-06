provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_cloudwatch_log_group" "vul-cloudwatch-log_group" {
  name              = "vuln-cloudwatch-log_group"
  retention_in_days = 0
}
