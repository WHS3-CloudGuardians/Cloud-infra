# custodian-setup/env/dev.tfvars

# 기본 계정 및 리전 정보
account_id  = "${ACCOUNT_ID}"
aws_region  = "${AWS_REGION}"

# Slack 알림용 Webhook
good_slack    = "${GOOD_SLACK}"
warning_slack = "${WARNING_SLACK}"
danger_slack  = "${DANGER_SLACK}"
