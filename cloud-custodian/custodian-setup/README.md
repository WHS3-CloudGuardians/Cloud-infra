# 🛡️ Cloud Custodian 자동화 인프라

**실시간 AWS 보안 정책 자동화 시스템**

이 프로젝트는 **Cloud Custodian**과 **Terraform**을 결합하여 AWS 환경의 보안 정책을 실시간으로 모니터링하고 자동 조치를 취하는 완전 자동화 인프라입니다. CloudTrail 이벤트를 실시간으로 감지하여 정책을 실행하고, 결과를 Slack으로 알림합니다.

**핵심 특징:**
- **실시간 감지**: AWS API 호출 즉시 정책 실행
- **이벤트 드리븐**: CloudTrail → EventBridge → Lambda 자동화
- **심각도별 알림**: 3단계 Slack 채널 분리 (Good/Warning/Danger)
- **장애 대응**: Dead Letter Queue로 실패 메시지 보존
- **모듈화**: 재사용 가능한 Terraform 모듈 구조

## 📁 프로젝트 구조

```
terraform/
├── 🔧 main.tf                     # 메인 Terraform 구성 (모듈 조합)
├── 📝 variables.tf                # 입력 변수 정의
├── 📤 outputs.tf                  # 배포 결과 출력
├── ⚙️ provider.tf                 # AWS Provider 설정
├── 🛠️ Makefile                   # 빌드/배포 자동화
│
├── 📂 env/
│   ├── 🌍 .env                    # 환경변수 중앙 관리
│   └── 📋 dev.tfvars              # Terraform 변수 (.env 참조)
│
├── 📂 modules/                    # 모듈화된 Terraform 코드
│   ├── 📬 custodian-sqs/          # SQS Queue + DLQ
│   ├── 🔐 custodian-iam/          # IAM 역할 및 정책
│   ├── 📋 custodian-trail/        # CloudTrail + S3 버킷
│   ├── ⚡ custodian-cloudtrail/   # Custodian Lambda 함수
│   └── 📧 custodian-mailer/       # 알림 발송 Lambda
│
├── 📂 policies/
│   └── cloudtrail/                # Custodian 정책 파일들
│
├── 🐍 custodian-lambda.py         # Lambda 진입점 핸들러
└── 📧 c7n-mailer.yml             # Mailer 설정 파일
```

## 🚀 설치 및 배포 가이드

### 1️⃣ 사전 준비
```bash
# AWS CLI 설정
aws configure

# 필요한 도구 설치 확인
terraform --version  # >= 1.0
python3 --version    # >= 3.11
make --version
```

### 2️⃣ 환경 설정
`terraform/.env` 파일을 환경에 맞게 수정:

```bash
# AWS 기본 설정
ACCOUNT_ID=123456789012
AWS_REGION=ap-northeast-2

# IAM 역할명 (기본값 사용 권장)
LAMBDA_ROLE=whs3-custodian-lambda-role
MAILER_ROLE=whs3-c7n-mailer-role

# SQS 큐 URL
QUEUE_URL=https://sqs.ap-northeast-2.amazonaws.com/123456789012/whs3-security-alert-queue

# Slack Webhook URLs (필수 수정 항목)
GOOD_SLACK=https://hooks.slack.com/services/T00000000/B00000000/YOUR-GOOD-WEBHOOK
WARNING_SLACK=https://hooks.slack.com/services/T00000000/B00000000/YOUR-WARNING-WEBHOOK
DANGER_SLACK=https://hooks.slack.com/services/T00000000/B00000000/YOUR-DANGER-WEBHOOK
```

### 3️⃣ Slack Webhook 설정
1. Slack 워크스페이스에서 **Incoming Webhooks** 앱 설치
2. 3개 채널별 Webhook URL 생성:
   - `#security-good`: 정상 작업 알림
   - `#security-warning`: 경고 수준 알림  
   - `#security-danger`: 위험 수준 알림

### 4️⃣ 배포 실행
```bash
# 프로젝트 디렉토리로 이동
cd terraform/

# 환경변수 로드
set -a && source .env && set +a

# Terraform 초기화
terraform init

# 전체 빌드 및 배포 (권장)
make all

# 또는 단계별 실행
make build      # Lambda 패키지 빌드
make plan       # 배포 계획 확인
make deploy     # 인프라 배포
```



## 📊 배포 결과 확인

### Terraform 출력 정보
```bash
terraform output
```

**주요 출력값**:
- `custodian_lambda_arn`: Custodian Lambda 함수 ARN
- `mailer_lambda_arn`: Mailer Lambda 함수 ARN
- `custodian_notify_queue_url`: SQS 큐 URL
- `trail_bucket_name`: CloudTrail 로그 S3 버킷명
- `cloudtrail_arn`: CloudTrail ARN

## 🧪 정책 실행 방식

### 1. CloudTrail 정책 (자동 실행) ⚡
`policies/cloudtrail/` 디렉토리의 정책들:
- ✅ **완전 자동화**: AWS 리소스 변경 즉시 자동 실행
- ❌ **수동 실행 불가**: `custodian run` 명령어 사용 불가
- 🔍 **구문 검사만 가능**: `custodian validate policies/cloudtrail/`

**테스트 방법**: 실제 AWS 리소스 변경으로만 가능
```bash
# 예시: EC2 인스턴스 생성하여 정책 트리거
aws ec2 run-instances --image-id ami-12345 --instance-type t2.micro

# 로그 확인
aws logs tail /aws/lambda/whs3-custodian-cloudtrail --follow
```

### 2. Periodic 정책 (수동 실행) 🔧
`policies/periodic/` 디렉토리에 정책을 만들면:
- ✅ `custodian run` 수동 실행 가능
- ✅ 드라이런 테스트 가능  
- ✅ 언제든 개발자가 직접 실행

**사용법**:
```bash
# 정책 생성
mkdir -p policies/periodic
vi policies/periodic/my-policy.yml

# 구문 검사
custodian validate policies/periodic/my-policy.yml

# 드라이런 (안전한 테스트)
custodian run --dryrun -s out policies/periodic/my-policy.yml

# 실제 실행
custodian run -s out policies/periodic/my-policy.yml
```
```bash
# EC2 인스턴스 생성 (CloudTrail 이벤트 발생)
aws ec2 run-instances --image-id ami-12345 --instance-type t2.micro

# 로그 확인
aws logs tail /aws/lambda/whs3-custodian-cloudtrail --follow
aws logs tail /aws/lambda/whs3-c7n-mailer --follow
```

### 3. Slack 알림 확인
- 정책 실행 후 해당 심각도 채널에 알림 도착 확인
- 메시지 포맷 및 내용 검증

