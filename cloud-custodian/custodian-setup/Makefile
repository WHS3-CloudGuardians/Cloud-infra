# custodian-setup/Makefile

# Makefile: Custodian (CloudTrail → Lambda → SQS) 인프라 배포 전용

.PHONY: all tfvars plan validate apply deploy-sqs deploy-policies run-cloudtrail run-periodic test-policies build-lambda clean

# 전체 배포: tfvars 생성 → validate → apply
all: tfvars validate apply

# .env 기반 dev.tfvars 자동 생성
# generate-dev-tfvars.sh를 사용하도록 변경

tfvars:
	@./generate-dev-tfvars.sh

# Terraform validate & plan
plan:
	@echo "🔎 Planning Terraform..."
	terraform plan -var-file=env/dev.tfvars

validate:
	@echo "🔎 Validating Terraform..."
	terraform validate

# 전체 배포 (apply)
apply:
	@echo "🚀 Applying Terraform..."
	terraform apply -var-file=env/dev.tfvars

# SQS만 배포
deploy-sqs:
	@echo "🚀 Deploying only SQS..."
	terraform apply -auto-approve -target=module.custodian_sqs -var-file=env/dev.tfvars

# 정책 배포 (템플릿 처리 + deploy)
deploy-policies:
	@echo "🔄 Processing policy templates..."
	@if [ ! -f .env ]; then echo "❌ .env file not found, cannot process policies."; exit 1; fi
	@. .env && \
	mkdir -p policies/processed && \
	for f in policies/*.yml; do \
		if [ -f "$$f" ]; then \
			echo "Processing $$f..."; \
			envsubst < "$$f" > "policies/processed/$$(basename $$f)"; \
		fi; \
	done
	@echo "🚀 Deploying policies..."
	@. .env && custodian deploy --region $$AWS_REGION policies/processed/

# CloudTrail 기반 정책 수동 실행
run-cloudtrail:
	@echo "📋 Running CloudTrail-based Custodian policies..."
	@if [ -d "policies/cloudtrail" ]; then \
		for f in policies/cloudtrail/*.yml; do \
			[ -f "$$f" ] || continue; \
			echo "→ $$f"; custodian run -s out "$$f"; \
		done; \
	else \
		echo "⚠️ No policies/cloudtrail directory found"; \
	fi

# Periodic 기반 정책 수동 실행
run-periodic:
	@echo "🕒 Running periodic Custodian policies..."
	@if [ -d "policies/periodic" ]; then \
		for f in policies/periodic/*.yml; do \
			[ -f "$$f" ] || continue; \
			echo "→ $$f"; custodian run -s out "$$f"; \
		done; \
	else \
		echo "⚠️ No policies/periodic directory found"; \
	fi

# 처리된 정책 테스트
test-policies:
	@echo "🧪 Testing policies..."
	@if [ ! -d "policies/processed" ]; then \
		echo "⚠️ No processed policies found. Run 'make deploy-policies' first."; \
		exit 1; \
	fi
	@. .env && custodian run --region $$AWS_REGION policies/processed/

# Lambda 핸들러 zip 빌드
build-lambda:
	@echo "📦 Zipping custodian_lambda.py into custodian.zip..."
	@if [ ! -f custodian_lambda.py ]; then echo "❌ custodian_lambda.py not found."; exit 1; fi
	@zip -j custodian.zip custodian_lambda.py
	@echo "✅ custodian.zip created"

# 정리
clean:
	@echo "🧹 Cleaning..."
	rm -rf .build out env/dev.tfvars custodian.zip policies/processed
