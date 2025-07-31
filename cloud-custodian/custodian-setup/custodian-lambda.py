import json
from c7n import handler as custodian_handler

def handler(event, context):
    """
    Lambda handler for processing CloudTrail events with Custodian
    """
    print("🪵 CloudTrail Event:", json.dumps(event, indent=2))
    return custodian_handler.run(event, context)
