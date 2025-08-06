#!/usr/bin/env bash
# bootstrap.sh
aws s3 mb s3://sub-jh-bucket --region ap-northeast-2
terraform init -upgrade
terraform apply -auto-approve
