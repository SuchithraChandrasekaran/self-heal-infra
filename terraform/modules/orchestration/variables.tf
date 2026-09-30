variable "toy_alarm_arn" {
  description = "ARN of the toy service CloudWatch alarm to watch for ALARM state"
  type        = string
}

variable "failure_mode_table_name" {
  description = "Name of the DynamoDB table holding the chaos/failure-mode flag"
  type        = string
}

variable "failure_mode_table_arn" {
  description = "ARN of the DynamoDB table holding the chaos/failure-mode flag"
  type        = string
}

variable "confidence_threshold" {
  description = "Minimum diagnosis confidence (0-1) required to auto-approve remediation"
  type        = number
  default     = 0.7
}

variable "max_retries" {
  description = "Circuit breaker: max remediation attempts before flagging for a human"
  type        = number
  default     = 3
}

variable "cooldown_seconds" {
  description = "Minimum seconds between pipeline runs, to prevent re-triggering on the same incident"
  type        = number
  default     = 120
}
