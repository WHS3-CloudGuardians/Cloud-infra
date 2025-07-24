import json
import boto3

iam = boto3.client("iam")

def lambda_handler(event, context):
    role_name = "SecurityAudit"
    assume_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }
        ]
    }
    inline_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "iam:List*",
                    "iam:Get*",
                    "iam:GenerateCredentialReport"
                ],
                "Resource": "*"
            }
        ]
    }
    try:
        iam.get_role(RoleName=role_name)
    except iam.exceptions.NoSuchEntityException:
        iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(assume_policy)
        )
        iam.put_role_policy(
            RoleName=role_name,
            PolicyName=f"{role_name}Policy",
            PolicyDocument=json.dumps(inline_policy)
        )
