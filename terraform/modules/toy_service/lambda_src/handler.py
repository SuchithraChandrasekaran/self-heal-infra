import json
import os
import time

import boto3

TABLE_NAME = os.environ.get("FAILURE_MODE_TABLE", "selfheal-failure-mode")
dynamodb = boto3.resource("dynamodb")


def get_failure_mode():
    """Reads the current chaos flag from DynamoDB. Defaults to healthy if missing."""
    table = dynamodb.Table(TABLE_NAME)
    result = table.get_item(Key={"id": "current"})
    item = result.get("Item")
    if not item:
        return "healthy"
    return item.get("mode", "healthy")


def handler(event, context):
    """
    Toy service for Self-Heal Infra.

    Day 2: checks the DynamoDB-backed chaos flag. When the flag is set to
    "degraded", the service simulates a failure (500 response) instead of
    responding healthy. This is what CloudWatch alarms watch for.
    """
    mode = get_failure_mode()

    if mode == "degraded":
        response_body = {
            "status": "degraded",
            "service": "self-heal-infra-toy-service",
            "timestamp": int(time.time()),
            "error": "simulated failure (chaos mode is on)",
        }
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(response_body),
        }

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
