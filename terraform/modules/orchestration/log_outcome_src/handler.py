import os
import time
import uuid
from decimal import Decimal

import boto3

TABLE_NAME = os.environ.get("INCIDENT_LOG_TABLE", "selfheal-incident-log")
dynamodb = boto3.resource("dynamodb")


def _convert_floats(obj):
    """DynamoDB's SDK rejects native Python floats - it wants Decimal."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: _convert_floats(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_convert_floats(v) for v in obj]
    return obj


def handler(event, context):
    """
    Writes the final outcome of a pipeline run to the incident log.

    This is the "reasoning trail" a dashboard reads to show what the
    agent noticed, decided, and did for a given incident.
    """
    table = dynamodb.Table(TABLE_NAME)

    incident_id = str(uuid.uuid4())
    item = {
        "id": incident_id,
        "logged_at": int(time.time()),
        "status": event.get("status", "unknown"),
        "diagnosis": _convert_floats(event.get("diagnosis", {})),
        "retry_count": event.get("retryCount", 0),
    }

    table.put_item(Item=item)
    return {"incident_id": incident_id, "status": item["status"]}
