import boto3
import json
import urllib3
import os

def lambda_handler(event, context):
    backup = boto3.client('backup')
    sts = boto3.client('sts')
    region = os.environ.get("AWS_REGION", "ap-northeast-2")

    response = backup.list_report_plans()
    report_plans = response.get('ReportPlans', [])

    # 조건: report plan이 없거나 상태가 비활성화됨
    if not report_plans or any(plan.get('ReportPlanStatus') != 'CREATED' for plan in report_plans):
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
                            "value": (
                                "N/A (No active Backup Report Plan found)"
                                if not report_plans else
                                "\n".join([f"{p['ReportPlanName']} = {p['ReportPlanStatus']}" for p in report_plans])
                            )
                        },
                        {
                            "title": "Region",
                            "value": region
                        },
                        {
                            "title": "Violation Description",
                            "value": (
                                "*** CHECKID: backup_report_plan_status ***\n"
                                "- AWS Backup Report Plan이 비활성화되어 있거나 존재하지 않습니다."
                            )
                        },
                        {
                            "title": "Action Description",
                            "value": (
                                "1. AWS Backup Report Plan을 활성화하여 백업 이행 상태를 자동으로 보고 받으세요."
                            )
                        }
                    ]
                }
            ],
            "username": "Custodian"
        }

        webhook_url = "${SLACK_WEBHOOK_URL}"  # Slack Webhook URL
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
            "status": "All report plans active",
            "report_plans": [p["ReportPlanName"] for p in report_plans]
        }
