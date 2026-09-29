import json
import os

import boto3

TABLE_NAME = os.environ.get("FAILURE_MODE_TABLE", "selfheal-failure-mode")
dynamodb = boto3.resource("dynamodb")


def handler(event, context):
    """
    Chaos toggle for Self-Heal Infra.

    Flips the shared failure-mode flag between "healthy" and "degraded".
    Called via POST /chaos from the frontend (or curl, for testing).
    """
    table = dynamodb.Table(TABLE_NAME)
    result = table.get_item(Key={"id": "current"})
    item = result.get("Item")
    current_mode = item.get("mode", "healthy") if item else "healthy"

    new_mode = "healthy" if current_mode == "degraded" else "degraded"
    table.put_item(Item={"id": "current", "mode": new_mode})

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"previous_mode": current_mode, "new_mode": new_mode}),
    }
