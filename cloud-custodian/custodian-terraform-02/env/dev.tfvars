# terraform\env\dev.tfvars

#########################################
# 기본 계정 및 리전 정보
#########################################

account_id = "001848367358"
aws_region = "ap-northeast-2"

#########################################
# CloudTrail S3 버킷 및 SQS 설정
#########################################

trail_bucket_name = "dev-cloudtrail-logs-bucket"
queue_name = "dev-custodian-notify-queue"
dlq_name   = "dev-custodian-notify-dlq"

#########################################
# (선택) 기본값을 사용하는 변수들
#########################################

lambda_role_name = "custodian-lambda-role"
mailer_role_name = "c7n-mailer-role"

message_retention_seconds = 1209600
max_receive_count         = 5