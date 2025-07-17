import boto3
import json
import urllib3
import os

def lambda_handler(event, context):
    backup = boto3.client('backup')
    sts = boto3.client('sts')
    region = os.environ.get("AWS_REGION", "ap-northeast-2")

    plans = backup.list_backup_plans()['BackupPlansList']

    if not plans:
        account_id = sts.get_caller_identity()['Account']
        
        slack_message = {
            "text": "Cloud Custodian",
            "attachments": [
                {
                    "fallback": "Cloud Custodian Policy Violation",
                    "title": "Custodian",
                    "color": "danger",
                    "fields": [
                        {
                            "title": "Resources",
                            "value": "N/A (No Backup Plan Found)"
                        },
                        {
                            "title": "Region",
                            "value": region
                        },
                        {
                            "title": "Violation Description",
                            "value": (
                                "*** CHECKID: backup_plans_exist ***\n"
                                "- AWS Backup Plan 누락이 감지되었습니다."
                            )
                        },
                        {
                            "title": "Action Description",
                            "value": (
                                "1. AWS Backup 계획을 수립하여 백업 일정 및 대상을 자동화해 주세요.\n"
                                "2. AWS Backup을 통해 리소스 유형별 백업 플랜을 구성 및 적용해 주세요."
                            )
                        }
                    ]
                }
            ],
            "username": "Custodian"
        }

        webhook_url = "${SLACK_WEBHOOK_URL}"  # 실제 Webhook URL로 교체
        http = urllib3.PoolManager()
        response = http.request(
            'POST',
            webhook_url,
            body=json.dumps(slack_message).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )

        return {
            "status": "alert_sent",
            "slack_response_code": response.status
        }

    else:
        return {
            "status": f"{len(plans)} backup plan(s) found",
            "details": [plan['BackupPlanName'] for plan in plans]
        }
