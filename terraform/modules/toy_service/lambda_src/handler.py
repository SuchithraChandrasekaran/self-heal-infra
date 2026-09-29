import json
import time


def handler(event, context):
    """
    Toy service for Self-Heal Infra.

    Day 1 version: always returns healthy. The chaos-toggle flag (DynamoDB-backed)
    and simulated failure behavior are added on Day 2.
    """
    response_body = {
        "status": "healthy",
        "service": "self-heal-infra-toy-service",
        "timestamp": int(time.time()),
    }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(response_body),
    }
