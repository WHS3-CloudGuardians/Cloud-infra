import os
import json
import boto3
from kafka import KafkaConsumer

def main(event, context):
    # AWS Lambda + MSK 용 예시 핸들러 (boto3는 IAM 인증용)
    records = event.get('records', {})
    for topic, recs in records.items():
        for r in recs:
            payload = r['value']
            print(f"Received: {payload}")
            # TODO: 파싱 후 비즈니스 로직 처리
    return {"statusCode": 200}
