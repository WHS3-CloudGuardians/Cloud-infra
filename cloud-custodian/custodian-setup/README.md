# 🛡️ Cloud Custodian 자동화 인프라

**실시간 AWS 보안 정책 자동화 시스템**

이 프로젝트는 **Cloud Custodian**과 **Terraform**을 결합하여 AWS 환경의 보안 정책을 실시간으로 모니터링하고 자동 조치를 취하는 완전 자동화 인프라입니다. CloudTrail 이벤트를 실시간으로 감지하여 정책을 실행하고, 결과를 Slack으로 알림합니다.

## 🏗️ 시스템 아키텍처

```
📊 AWS API 호출 → 📋 CloudTrail → ⚡ EventBridge → 🔧 Custodian Lambda
                                                           ↓
📢 Slack 알림 ← 📧 Mailer Lambda ← 📬 SQS Queue ← 🔄 정책 실행 결과
```

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


## 🧪 테스트 및 검증

### 1. 정책 수동 실행 (로컬 테스트)
```bash
# 정책 파일 구문 검사
custodian validate policies/cloudtrail/

# 드라이런 (실제 조치 없이 대상만 확인)
custodian run --dryrun -s out policies/cloudtrail/s3-public-access.yml

# 실제 정책 실행
custodian run -s out policies/cloudtrail/s3-public-access.yml
```

### 2. 실시간 시스템 테스트
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

## 🛠️ 운영 및 관리

### 로그 모니터링
- **CloudWatch Logs**: `/aws/lambda/whs3-*` 로그 그룹
- **SQS 메트릭**: 큐 깊이, 처리 속도 모니터링
- **DLQ 확인**: 실패 메시지 주기적 점검

### 정책 업데이트
```bash
# 정책 파일 수정 후
make build-cloudtrail  # 새 패키지 빌드
terraform apply -var-file=env/dev.tfvars  # Lambda 함수 업데이트
```

### 리소스 정리
```bash
make clean              # 빌드 아티팩트 정리
terraform destroy       # 전체 인프라 삭제
```

## 🔧 고급 설정

### 환경별 배포
```bash
# 프로덕션 환경 변수 파일 생성
cp env/dev.tfvars env/prod.tfvars

# 프로덕션 배포
terraform apply -var-file=env/prod.tfvars
```

### 알림 채널 추가
`c7n-mailer.yml`에서 추가 Slack 채널 설정:
```yaml
slack:
  channels:
    - channel: "#security-critical"
      webhook: "${CRITICAL_SLACK}"
```

### 정책 커스터마이징
`policies/cloudtrail/` 디렉토리에 새 정책 파일 추가 후 빌드

## 🚨 문제 해결

### 일반적인 이슈

**Lambda 패키지 크기 초과**:
```bash
# 불필요한 패키지 제외하여 재빌드
make clean && make build
```

**SQS 메시지 누적**:
- DLQ 메시지 확인 및 처리
- Mailer Lambda 로그 점검

**Slack 알림 미도착**:
- Webhook URL 유효성 확인
- 네트워크 연결 상태 점검

### 디버깅 명령어
```bash
# 빌드 결과 상세 확인
make debug-build

# Terraform 설정 검증
make debug-tf

# 전체 디버깅
make debug
```

## 📚 참고 자료
- [Cloud Custodian 공식 문서](https://cloudcustodian.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws)
- [AWS CloudTrail 가이드](https://docs.aws.amazon.com/cloudtrail/)

## 🤝 기여하기
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 라이선스
이 프로젝트는 MIT 라이선스 하에 배포됩니다.

---
⚡ **빠른 시작**: `make all` 명령어 하나로 전체 시스템을 배포할 수 있습니다!
