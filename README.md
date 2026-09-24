# Self-Heal Infra

Self-Heal Infra is a AWS project that detects a failing service, figures out what's wrong, and fixes it, without paging a human.

Built for the AWS Zero to Shipped Hackathon

## The problem

A lot of incidents follow the same shape: something breaks in a predictable way, an engineer gets paged, they look at a dashboard, recognize the pattern, and apply a fix they've applied before. That diagnosis-and-fix step doesn't need to wait for a person to wake up. This project automates it for one specific class of failure, end to end, and shows its work while it does it.

## What it does

The project runs a small demo service that can be pushed into a failing state on demand. When it fails, an agent notices, looks at the logs and metrics, proposes a cause and a fix, applies the fix, and checks that it worked. Every step is written to a log you can watch in real time, so the reasoning isn't hidden — you can see what the agent noticed, what it decided, and what it did.

## How it works

1. **Toy service** — a small Lambda-backed API with a chaos toggle. Flipping the toggle pushes it into a failing state.
2. **Detection** — a CloudWatch alarm watches the service's health metric. When it fires, an EventBridge rule starts the response pipeline.
3. **Orchestration** — a Step Functions state machine runs the pipeline in order: detect, diagnose, get approval, remediate, verify, log.
4. **Diagnosis** — a Lambda function sends recent metrics and logs to an LLM (via Amazon Bedrock) and asks for a likely cause and a recommended fix.
5. **Remediation** — a separate Lambda applies only a small set of pre-approved, reversible actions. It doesn't have permission to do anything else.
6. **Verification and logging** — the pipeline confirms the fix worked and writes the full sequence of events to DynamoDB.
7. **Dashboard** — a static page shows the current status and the live reasoning trail. A Grafana dashboard (backed by CloudWatch and X-Ray) shows the same incident from the infrastructure side.
8. **The operational agent**  - the part that actually runs inside AWS after deployment — the Lambda-and-Bedrock loop that watches for problems and responds to them.

## Project layout

```
selfheal-infra/
├── .github/workflows/deploy.yml     # CI: plan on PR, apply on merge
├── terraform/
│   ├── main.tf                      # Provider config, budget alert, module wiring
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── toy_service/             # Demo app and chaos toggle
│       ├── agent/                   # Diagnostic and remediation Lambdas, IAM
│       └── orchestration/           # Step Functions state machine, EventBridge rules
└── src/
    ├── diagnostic_agent/            # Root-cause reasoning logic
    └── remediation_worker/          # The small set of allowed fix actions
```

## Stack

AWS Lambda, API Gateway, DynamoDB, EventBridge, Step Functions, CloudWatch, X-Ray, Amazon Bedrock, Terraform, GitHub Actions, and Grafana Cloud (free tier) for the dashboard.

## Why it's safe to let an agent make changes automatically

An agent that can take action on its own needs limits, or it becomes its own incident. A few are built in:

- **Cooldown** — after responding to an incident, the pipeline won't respond again to the same one for a set window, so it can't get stuck in a loop.
- **Circuit breaker** — if a fix fails a set number of times, the pipeline stops trying and flags it for a person instead of retrying indefinitely.
- **Scoped permissions** — the remediation Lambda can only touch the specific resources it needs to. It has no broader access to the account.
- **Spending cap** — an AWS Budget set to $1 with an email alert, so the free-tier assumption is enforced rather than just hoped for.

## Category and track

- **Category:** Workplace Efficiency
- **Track:** Startup

## Cost

Everything runs on AWS's free tier at demo scale — Lambda, DynamoDB, EventBridge, Step Functions, API Gateway, CloudWatch, X-Ray, and S3 static hosting. Cost to run this project: $0.

## Demo

- **Live app:** 
- **Demo video:** 
- **Builder Center listing:** 
