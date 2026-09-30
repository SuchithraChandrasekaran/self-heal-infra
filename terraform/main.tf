terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "SelfHealInfra"
      ManagedBy = "Terraform"
      Hackathon = "AWS-Zero-To-Shipped"
    }
  }
}

# Cost guardrail: alert if spend exceeds $1, keeping this strictly inside free tier
resource "aws_budgets_budget" "cost_guardrail" {
  name         = "selfheal-infra-free-tier-guardrail"
  budget_type  = "COST"
  limit_amount = "1.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.admin_email]
  }
}

module "toy_service" {
  source = "./modules/toy_service"
}

module "orchestration" {
  source                  = "./modules/orchestration"
  toy_alarm_arn           = module.toy_service.alarm_arn
  failure_mode_table_name = module.toy_service.failure_mode_table_name
  failure_mode_table_arn  = module.toy_service.failure_mode_table_arn
}
