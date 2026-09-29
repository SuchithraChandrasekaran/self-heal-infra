import json


def handler(event, context):
    """
    Placeholder for Self-Heal Infra's detection step.

    Day 2: just logs the incoming CloudWatch Alarm event from EventBridge,
    to confirm the detection wiring works end to end. Day 3 replaces this
    Lambda's role with a Step Functions state machine that actually
    diagnoses and remediates.
    """
    print("ALARM EVENT RECEIVED:")
    print(json.dumps(event))
    return {"statusCode": 200, "body": "logged"}
