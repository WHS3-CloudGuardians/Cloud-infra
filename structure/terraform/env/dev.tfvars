# terraform\env\dev.tfvars

#########################################
# 기본 계정 및 리전 정보
#########################################

account_id = "311278774159"
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

# lambda_role_name            = "dev-custodian-lambda-role"
# mailer_role_name            = "dev-c7n-mailer-role"
# message_retention_seconds   = 1209600  # 14일 (기본값)
# max_receive_count           = 5        # DLQ로 보내기 전 최대 재시도 횟수
