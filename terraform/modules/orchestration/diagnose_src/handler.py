import time


def handler(event, context):
    """
    Diagnostic agent stub.

    Day 3: returns a hardcoded diagnosis so the pipeline can be built and
    tested end to end. Day 4 replaces this with a real call to an LLM
    (via Amazon Bedrock), passing in actual CloudWatch metrics/logs and
    asking for a genuine root-cause analysis and confidence score.
    """
    return {
        "root_cause": "toy service is returning simulated failures (chaos mode is on)",
        "confidence": 0.92,
        "recommended_action": "reset_failure_flag",
        "diagnosed_at": int(time.time()),
    }
