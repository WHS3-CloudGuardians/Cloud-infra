# ☁Cloud Custodian 자동화 인프라 (with Terraform)

Terraform을 활용해 AWS 환경에서 Cloud Custodian 정책 실행 및 Slack 알림 연동이 가능한 보안 자동화 인프라를 구성할 수 있습니다.

---

## 구성 요소

- **SQS & DLQ**: 정책 알림 큐 및 실패 메시지 큐
- **IAM Roles**: Lambda 실행 권한 정의
- **CloudTrail + S3**: 리소스 변경 기록 로깅
- **c7n-mailer Lambda**: SQS 메시지를 Slack 또는 이메일로 전송
- **모듈화된 구조**로 재사용 및 확장 가능

---

## 디렉터리 구조

<pre>
terraform/
├── main.tf                  # 모듈 조합 구성
├── provider.tf              # Terraform & AWS provider 설정
├── variables.tf             # 변수 정의
├── outputs.tf               # 출력값 정의
├── terraform.env            # 환경변수 export 스크립트 (선택)
├── Makefile                 # build / apply 자동화 명령어
│
├── env/
│   └── dev.tfvars           # 변수 값 정의 파일
│
└── modules/
    ├── custodian-sqs/       # SQS 및 DLQ 모듈
    ├── custodian-iam/       # IAM 역할 및 정책
    ├── custodian-trail/     # CloudTrail + S3 구성
    └── custodian-mailer/    # c7n-mailer Lambda 정의
</pre>

---

## 사전 준비

```bash
aws configure
```

> 본인의 Access Key, Secret Key, 리전 (`ap-northeast-2`) 입력

---

## 2. 환경 변수 설정 및 적용

`.env` 또는 `terraform.env` 파일에서 본인의 Account ID, Slack Webhook 등을 설정한 뒤, 아래 내용을 복사해서 한 번에 실행하세요:

```bash
export TF_VAR_account_id=123456789012
export TF_VAR_aws_region=ap-northeast-2

export TF_VAR_lambda_role_name="custodian-lambda-role"
export TF_VAR_mailer_role_name="c7n-mailer-role"
export TF_VAR_queue_name="custodian-notify-queue"
export TF_VAR_dlq_name="custodian-notify-dlq"
export TF_VAR_trail_bucket_name="custodian-cloudtrail-logs"

export TF_VAR_good_slack="https://hooks.slack.com/services/AAA/BBB/CCC"
export TF_VAR_warning_slack="https://hooks.slack.com/services/DDD/EEE/FFF"
export TF_VAR_danger_slack="https://hooks.slack.com/services/GGG/HHH/III"

source terraform.env
```

---

## 실행 순서

### 1. c7n-mailer 패키지 빌드

```bash
make build
```

> 약 5~7분 소요 (의존성 설치 포함)

빌드 결과 확인:

```bash
ls -lh modules/custodian-mailer/c7n-mailer.zip
```

---

### 2. Terraform 초기화 및 배포

```bash
terraform init
terraform apply -var-file=env/dev.tfvars
```

---

## Custodian 정책 실행 예시
정책 실행:

```bash
custodian run -s out custodian.yml
```

---

## Lambda 배포

### Terraform으로 배포

- `modules/custodian-mailer` 내부에 Lambda 정의
- `make build && make deploy`로 자동 배포

---

## 실행 후 출력 확인

```bash
terraform output
```

출력 예시:

- `custodian_lambda_role_arn`
- `custodian_notify_queue_url`
- `trail_bucket_name`
- `cloudtrail_arn`

---

## 참고

- Lambda 로그: **CloudWatch > /aws/lambda/c7n-mailer-***  
- Webhook URL은 `.env`, `terraform.env`, 또는 `mailer.yaml`에 정의
- `.build/`, `.zip` 파일은 `.gitignore`에 추가 권장

---
