# --- DynamoDB tables ---

resource "aws_dynamodb_table" "orchestration_meta" {
  name         = "selfheal-orchestration-meta"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "incident_log" {
  name         = "selfheal-incident-log"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# --- Cooldown gate Lambda ---

data "archive_file" "cooldown_gate_zip" {
  type        = "zip"
  source_dir  = "${path.module}/cooldown_gate_src"
  output_path = "${path.module}/cooldown_gate_src.zip"
}

resource "aws_iam_role" "cooldown_gate_role" {
  name = "selfheal-cooldown-gate-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cooldown_gate_logs" {
  role       = aws_iam_role.cooldown_gate_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "cooldown_gate_dynamo" {
  name = "selfheal-cooldown-gate-dynamo"
  role = aws_iam_role.cooldown_gate_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
      Resource = aws_dynamodb_table.orchestration_meta.arn
    }]
  })
}

resource "aws_lambda_function" "cooldown_gate" {
  function_name    = "selfheal-cooldown-gate"
  role             = aws_iam_role.cooldown_gate_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.cooldown_gate_zip.output_path
  source_code_hash = data.archive_file.cooldown_gate_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      META_TABLE       = aws_dynamodb_table.orchestration_meta.name
      COOLDOWN_SECONDS = tostring(var.cooldown_seconds)
    }
  }
}

# --- Diagnose Lambda (stub for Day 3, real LLM call added Day 4) ---

data "archive_file" "diagnose_zip" {
  type        = "zip"
  source_dir  = "${path.module}/diagnose_src"
  output_path = "${path.module}/diagnose_src.zip"
}

resource "aws_iam_role" "diagnose_role" {
  name = "selfheal-diagnose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "diagnose_logs" {
  role       = aws_iam_role.diagnose_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "diagnose" {
  function_name    = "selfheal-diagnose"
  role             = aws_iam_role.diagnose_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.diagnose_zip.output_path
  source_code_hash = data.archive_file.diagnose_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128
}

# --- Outcome logger Lambda ---

data "archive_file" "log_outcome_zip" {
  type        = "zip"
  source_dir  = "${path.module}/log_outcome_src"
  output_path = "${path.module}/log_outcome_src.zip"
}

resource "aws_iam_role" "log_outcome_role" {
  name = "selfheal-log-outcome-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "log_outcome_logs" {
  role       = aws_iam_role.log_outcome_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "log_outcome_dynamo" {
  name = "selfheal-log-outcome-dynamo"
  role = aws_iam_role.log_outcome_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = aws_dynamodb_table.incident_log.arn
    }]
  })
}

resource "aws_lambda_function" "log_outcome" {
  function_name    = "selfheal-log-outcome"
  role             = aws_iam_role.log_outcome_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.log_outcome_zip.output_path
  source_code_hash = data.archive_file.log_outcome_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      INCIDENT_LOG_TABLE = aws_dynamodb_table.incident_log.name
    }
  }
}

# --- Step Functions state machine ---

resource "aws_iam_role" "state_machine_role" {
  name = "selfheal-state-machine-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

# Least-privilege: the state machine can only invoke its own three Lambdas
# and read/write the one DynamoDB table it needs for remediate/verify.
resource "aws_iam_role_policy" "state_machine_policy" {
  name = "selfheal-state-machine-policy"
  role = aws_iam_role.state_machine_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.cooldown_gate.arn,
          aws_lambda_function.diagnose.arn,
          aws_lambda_function.log_outcome.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = var.failure_mode_table_arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "self_heal_pipeline" {
  name     = "selfheal-pipeline"
  role_arn = aws_iam_role.state_machine_role.arn

  definition = templatefile("${path.module}/state_machine.asl.json", {
    cooldown_gate_arn        = aws_lambda_function.cooldown_gate.arn
    diagnose_arn             = aws_lambda_function.diagnose.arn
    log_outcome_arn          = aws_lambda_function.log_outcome.arn
    failure_mode_table_name  = var.failure_mode_table_name
    confidence_threshold     = var.confidence_threshold
    max_retries              = var.max_retries
  })
}

# --- EventBridge: watches the toy service alarm, starts the pipeline ---

resource "aws_cloudwatch_event_rule" "toy_service_alarm_rule" {
  name        = "selfheal-toy-service-alarm-rule"
  description = "Fires when the toy service error alarm changes to ALARM state"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    resources   = [var.toy_alarm_arn]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })
}

resource "aws_iam_role" "eventbridge_role" {
  name = "selfheal-eventbridge-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_start_execution" {
  name = "selfheal-eventbridge-start-execution"
  role = aws_iam_role.eventbridge_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.self_heal_pipeline.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "pipeline_target" {
  rule     = aws_cloudwatch_event_rule.toy_service_alarm_rule.name
  arn      = aws_sfn_state_machine.self_heal_pipeline.arn
  role_arn = aws_iam_role.eventbridge_role.arn
}
