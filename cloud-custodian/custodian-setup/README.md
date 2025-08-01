# 🛡️ Cloud Custodian 자동화 인프라 (Terraform 기반)

이 프로젝트는 AWS 보안 정책을 자동으로 탐지하고 알림 및 대응하는 **Cloud Custodian 기반 자동화 인프라**입니다. Terraform으로 구성된 이 시스템은 CloudTrail 이벤트 발생 시 보안 위반 사항을 자동 감지하고, SQS를 통해 Slack 또는 이메일로 알림을 전송합니다.

---

## 🚀 핵심 특징

* **CloudTrail 실시간 이벤트 감지** → Lambda 트리거
* **Cloud Custodian 정책 자동 실행** → SQS 메시지 생성
* **c7n-mailer**로 Slack 알림 연동 (심각도별 Webhook 분리)
* **Dead Letter Queue**로 메시지 유실 방지
* **모듈화된 Terraform 코드**로 유연한 재사용 가능

---

## 📁 디렉토리 구조

```
terraform/
├── main.tf                    # 전체 인프라 구성
├── variables.tf              # 공통 변수 정의
├── outputs.tf                # 결과 출력
├── provider.tf               # AWS provider 정의
├── Makefile                  # Lambda 빌드 및 Terraform 자동화
├── custodian_lambda.py       # CloudTrail Lambda 핸들러
├── c7n-mailer.yml            # c7n-mailer 설정 파일
├── generate-dev-tfvars.sh    # .env → dev.tfvars 자동 생성
│
├── env/
│   └── dev.tfvars            # 환경별 변수 정의 (.env 기반 생성)
│
├── modules/
│   ├── custodian-iam/        # Lambda 및 mailer IAM 역할
│   ├── custodian-sqs/        # SQS + DLQ 구성
│   └── custodian-trail/      # CloudTrail + 로그용 S3 버킷
│
├── policies/
│   ├── cloudtrail/           # mode: cloudtrail 정책
│   └── periodic/             # mode: periodic 정책
```

---

## ⚙️ 설치 및 실행 방법

### 1. 필수 도구 설치

```bash
terraform -v        # >= 1.0
python3 --version   # >= 3.11
make --version
```

### 2. 환경변수 파일 생성

`.env` 파일 작성 예시:

```bash
ACCOUNT_ID=001848367358
AWS_REGION=ap-northeast-2
LAMBDA_ROLE=whs3-custodian-lambda-role
QUEUE_URL=https://sqs.ap-northeast-2.amazonaws.com/123456789012/whs3-security-alert-queue
GOOD_SLACK=https://hooks.slack.com/services/T00000000/B00000000/GOOD
WARNING_SLACK=https://hooks.slack.com/services/T00000000/B00000000/WARNING
DANGER_SLACK=https://hooks.slack.com/services/T00000000/B00000000/DANGER
```

### 3. Terraform 배포

```bash
# dev.tfvars 자동 생성
./generate-dev-tfvars.sh

# Terraform 초기화
terraform init

# 전체 인프라 배포 (build + deploy)
make all
```

---

## 🧪 정책 실행 방법

### ✅ Type: CloudTrail

**예시 정책 경로**: `policies/cloudtrail/s3-public-access-block.yml`

```bash
# 테스트 예시: S3 퍼블릭 접근 차단 해제
aws s3api delete-public-access-block --bucket your-bucket-name
```

### ✅ Type: Periodic

**예시 정책 경로**: `policies/periodic/alert-mfa-delete-disabled-s3.yml`

```bash
# 구문 확인
custodian validate policies/periodic/alert-mfa-delete-disabled-s3.yml

# 실행
custodian run -s out policies/periodic/alert-mfa-delete-disabled-s3.yml
```

---

## 📦 Makefile 주요 명령어

```bash
make all              # 전체 배포(tfvars + validate + apply)
make tfvars           # .env → dev.tfvars 생성
make build-lambda     # custodian_lambda.py → .zip 패키징
make deploy-policies  # 모든 정책 deploy (envsubst)
make run-cloudtrail   # cloudtrail 정책 직접 실행 (예외적 테스트용)
make run-periodic     # periodic 정책 직접 실행
```

---

## 📤 Terraform 출력값 예시

```bash
terraform output
```

* `custodian_notify_queue_url`
* `trail_bucket_name`
* `cloudtrail_arn`
* `custodian_lambda_role_arn`
* `eventbridge_rule_arn`

---

## 📡 Slack 알림 연동 방법

1. Slack 앱에서 "Incoming Webhook" 설치
2. Webhook URL 3개 생성

   * GOOD / WARNING / DANGER 채널 분리
3. `.env`에 각각 환경변수로 입력

---

## 📚 참고

* [Cloud Custodian 공식 문서](https://cloudcustodian.io/docs/aws/index.html)
* [c7n-mailer GitHub](https://github.com/cloud-custodian/cloud-custodian/tree/master/tools/c7n_mailer)

---

## ✅ 프로젝트 상태

* [x] Terraform 모듈화 구성 완료
* [x] CloudTrail → EventBridge → Lambda 연동
* [x] SQS 및 c7n-mailer 알림 처리 검증
* [x] 정책 수동 실행 (`custodian run`) 및 자동 실행 모두 구현

---

> 작성자: **영민 나**
> 배포 환경: AWS (001848367358 / ap-northeast-2)
