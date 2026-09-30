# Self-Heal Infra

Self-Heal Infra is a small AWS project that detects a failing service, runs it through an automated decision pipeline, and fixes it — without involving a human.

Built for the AWS Zero to Shipped Hackathon (September 18 – October 2, 2026).

## The problem

A lot of incidents follow the same shape: something breaks in a predictable way, an engineer gets paged, they recognize the pattern, and apply a fix they've applied before. That response doesn't need to wait for a person to wake up. This project automates it for one specific, deliberately simple class of failure, end to end, and logs its reasoning while it does it.

## What it does

The project runs a small demo service that can be pushed into a failing state on demand, using a chaos toggle. When it fails, a Step Functions pipeline detects it, runs a diagnosis step, checks a confidence threshold, applies a fix, and verifies the fix worked. It's been run and confirmed working twice, independently — the service returns to healthy on its own, with no manual intervention after the initial chaos trigger.

## How it actually works

1. **Toy service** — a Lambda behind API Gateway (`GET /health`). A second Lambda (`POST /chaos`) flips a DynamoDB flag that the toy service checks; when the flag is set, it returns a simulated failure.
2. **Detection** — a CloudWatch alarm watches API Gateway's 5xx count. When it fires, an EventBridge rule starts a Step Functions execution.
3. **Cooldown check** — the first state in the pipeline checks a DynamoDB-backed cooldown flag, so an incident that's already being handled doesn't trigger a second overlapping run.
4. **Diagnosis** — currently a stub Lambda that returns a fixed root cause and confidence score. It does not call an LLM. Replacing this with a real model call (via Bedrock or another provider) is the most obvious next step, not something already built.
5. **Approval gate** — a Choice state checks the diagnosis confidence against a threshold. Below it, the run goes straight to a "needs human" branch instead of acting automatically.
6. **Remediation** — a direct Step Functions task writes the fix (resetting the failure flag) straight to DynamoDB. There's no separate remediation Lambda — it's a scoped, single-purpose write built into the state machine itself.
7. **Verification** — another direct DynamoDB read confirms the flag actually changed. If it didn't, the pipeline retries remediation, up to a fixed limit, before giving up and flagging for a human.
8. **Logging** — a Lambda writes the outcome (status, diagnosis, retry count) to a DynamoDB incident log.

## Actual project layout

```
self-heal-infra/
├── LICENSE
├── docs/
│   ├── agent-connection-proof.md
│   └── agent-connection-proof-*.png
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        ├── toy_service/       # Toy Lambda, chaos-toggle Lambda, API Gateway, DynamoDB flag, CloudWatch alarm
        └── orchestration/     # Step Functions pipeline, cooldown/diagnose/log Lambdas, EventBridge trigger
```

## Actual stack

AWS Lambda, API Gateway (HTTP API), DynamoDB, CloudWatch (alarms), EventBridge, Step Functions, Terraform, deployed and applied manually via the AWS CLI.

Not used, despite earlier drafts of this README claiming otherwise: Amazon Bedrock, AWS X-Ray, Grafana, GitHub Actions/CI-CD, S3-hosted frontend. None of these are part of the current build.

## Safety measures that are actually implemented

- **Cooldown** — a persisted DynamoDB flag prevents a second pipeline run from starting while one is still within its cooldown window.
- **Retry limit / circuit breaker** — remediation retries up to a fixed count within a single execution before the pipeline gives up and flags the incident for a human, instead of retrying indefinitely.
- **Least-privilege IAM** — each Lambda has its own role, scoped only to the specific DynamoDB table or resource it needs.
- **Spending cap** — an AWS Budget set to $1 with an email alert.

## Category and track

- **Category:** Workplace Efficiency
- **Track:** Startup

## Cost

Runs on AWS's free tier at this demo's scale: Lambda, DynamoDB, EventBridge, Step Functions, API Gateway, and CloudWatch. Cost to run: effectively $0.
