#custodian-setup\generate-dev-tfvars.sh

#!/bin/bash

set -e
set -a
. "$(cd "$(dirname "$0")" && pwd)/.env"
set +a

mkdir -p env

cat > env/dev.tfvars <<VARS
account_id         = "${ACCOUNT_ID}"
aws_region         = "${AWS_REGION}"

lambda_role_name   = "${LAMBDA_ROLE}"
queue_url          = "${QUEUE_URL}"
trail_bucket_name  = "whs3-custodian-trail-logs-${ACCOUNT_ID}"

good_slack         = "${GOOD_SLACK}"
warning_slack      = "${WARNING_SLACK}"
danger_slack       = "${DANGER_SLACK}"
VARS

echo "✅ env/dev.tfvars 생성 완료"
