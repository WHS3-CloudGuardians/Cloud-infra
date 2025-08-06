//생성된 주요 값들을 출력해 두면 나중에 참조하기 편하다.

# output "msk_bootstrap_tls" {
#   description = "MSK TLS endpoint"
#   value       = module.msk.cluster_bootstrap_brokers_tls
# }

output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = aws_lambda_function.msk_consumer.function_name
}

locals {
  region = var.region
}