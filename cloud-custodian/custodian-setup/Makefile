# custodian-setup/Makefile

ZIP_PATH_MAILER = modules/custodian-mailer/c7n-mailer.zip
BUILD_DIR_MAILER = .build/c7n-mailer

ZIP_PATH_CT = modules/custodian-cloudtrail/custodian.zip
BUILD_DIR_CT = .build/custodian-cloudtrail

.PHONY: all plan validate build build-mailer build-cloudtrail deploy clean debug-build debug-tf debug

all: build deploy

plan: build
	@echo "🔎 Planning Terraform..."
	terraform plan -var-file=env/dev.tfvars

validate:
	@echo "🔎 Validating Terraform..."
	terraform validate

build: build-mailer build-cloudtrail

# 1) c7n-mailer 패키징
build-mailer:
	@echo "🔧 Building c7n-mailer.zip..."
	rm -rf $(BUILD_DIR_MAILER)
	mkdir -p $(BUILD_DIR_MAILER)/templates
	cp c7n-mailer.yml $(BUILD_DIR_MAILER)/
	cp -r templates/* $(BUILD_DIR_MAILER)/templates/
	pip install c7n-mailer -t $(BUILD_DIR_MAILER)
	cd $(BUILD_DIR_MAILER) && zip -r ../../$(ZIP_PATH_MAILER) .

# 2) custodian-cloudtrail 패키징
build-cloudtrail:
	@echo "🔧 Building custodian-cloudtrail.zip..."
	rm -rf $(BUILD_DIR_CT)
	mkdir -p $(BUILD_DIR_CT)
	pip install c7n[boto3] -t $(BUILD_DIR_CT)
	cp -r policies/cloudtrail $(BUILD_DIR_CT)/policies
	cp custodian-lambda.py $(BUILD_DIR_CT)/custodian_lambda.py
	cd $(BUILD_DIR_CT) && zip -r ../../$(ZIP_PATH_CT) .

deploy: build
	@echo "🚀 Deploying with Terraform..."
	terraform apply -auto-approve -var-file=env/dev.tfvars

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf .build
	rm -f $(ZIP_PATH_MAILER) $(ZIP_PATH_CT)

# ──────────────────────────────────────────────────────
# 디버깅 전용 타겟
# ──────────────────────────────────────────────────────

debug-build:
	@echo "🔍 Inspecting mailer build…"    # TAB으로 들여쓰기
	tree $(BUILD_DIR_MAILER) || echo "⚠️ tree not found"
	unzip -l $(ZIP_PATH_MAILER)
	@echo "🔍 Inspecting cloudtrail build…"
	tree $(BUILD_DIR_CT)     || echo "⚠️ tree not found"
	unzip -l $(ZIP_PATH_CT)

debug-tf: plan validate
	@echo "🔍 Terraform checks completed"

debug: debug-build debug-tf
