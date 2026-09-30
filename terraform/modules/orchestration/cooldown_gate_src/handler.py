import os
import time

import boto3

TABLE_NAME = os.environ.get("META_TABLE", "selfheal-orchestration-meta")
COOLDOWN_SECONDS = int(os.environ.get("COOLDOWN_SECONDS", "120"))
dynamodb = boto3.resource("dynamodb")


def handler(event, context):
    """
    Cooldown gate: the first state in the pipeline.

    Checks whether a pipeline run already happened recently. If so, this
    run is skipped (in_cooldown = true) so the same incident can't
    re-trigger a flood of remediation attempts. If not in cooldown, it
    starts a new cooldown window and lets the run proceed.
    """
    table = dynamodb.Table(TABLE_NAME)
    now = int(time.time())

    result = table.get_item(Key={"id": "cooldown"})
    item = result.get("Item")
    cooldown_until = int(item.get("cooldown_until", 0)) if item else 0

    if now < cooldown_until:
        return {"in_cooldown": True, "cooldown_until": cooldown_until}

    table.put_item(Item={"id": "cooldown", "cooldown_until": now + COOLDOWN_SECONDS})
    return {"in_cooldown": False, "cooldown_until": now + COOLDOWN_SECONDS}
