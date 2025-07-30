# 환경 변수 로드 (필요시 .env 지원)
include .env
export

ZIP_PATH=modules/custodian-mailer/c7n-mailer.zip
BUILD_DIR=.build/c7n-mailer

.PHONY:  all clean build deploy plan validate

# 전체 작업: zip 생성 → Terraform apply
all: build deploy

# Terraform Plan
plan:
	terraform plan -var-file=env/dev.tfvars

# Terraform Validate
validate:
	@echo "🔎 Validating Terraform code..."
	terraform validate

# c7n-mailer 패키지 빌드
build:
	@echo "🔧 Building c7n-mailer.zip..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/templates
	cp c7n-mailer.yml $(BUILD_DIR)/
	cp -r templates/* $(BUILD_DIR)/templates/
	pip install c7n-mailer -t $(BUILD_DIR)
	cd $(BUILD_DIR) && zip -r ../../$(ZIP_PATH) .

# Terraform 배포
deploy:
	@echo "🚀 Running terraform apply..."
	terraform apply -auto-approve

# 정리
clean:
	rm -rf .build
	rm -f $(ZIP_PATH)
