data "archive_file" "toy_service_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda_src.zip"
}

data "archive_file" "chaos_toggle_zip" {
  type        = "zip"
  source_dir  = "${path.module}/chaos_toggle_src"
  output_path = "${path.module}/chaos_toggle_src.zip"
}

# DynamoDB table holding the single chaos flag. On-demand billing keeps this
# inside the DynamoDB always-free allowance at this tiny scale.
resource "aws_dynamodb_table" "failure_mode" {
  name         = "selfheal-failure-mode"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "toy_service_role" {
  name = "selfheal-toy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "toy_service_logs" {
  role       = aws_iam_role.toy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least-privilege: toy service can only READ the failure-mode flag.
resource "aws_iam_role_policy" "toy_service_dynamo_read" {
  name = "selfheal-toy-service-dynamo-read"
  role = aws_iam_role.toy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem"]
      Resource = aws_dynamodb_table.failure_mode.arn
    }]
  })
}

resource "aws_iam_role" "chaos_toggle_role" {
  name = "selfheal-chaos-toggle-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "chaos_toggle_logs" {
  role       = aws_iam_role.chaos_toggle_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least-privilege: chaos toggle can READ and WRITE only the failure-mode flag.
resource "aws_iam_role_policy" "chaos_toggle_dynamo_readwrite" {
  name = "selfheal-chaos-toggle-dynamo-readwrite"
  role = aws_iam_role.chaos_toggle_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
      Resource = aws_dynamodb_table.failure_mode.arn
    }]
  })
}

resource "aws_lambda_function" "toy_service" {
  function_name    = "selfheal-toy-service"
  role             = aws_iam_role.toy_service_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.toy_service_zip.output_path
  source_code_hash = data.archive_file.toy_service_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128 # smallest size, stays comfortably in free tier

  environment {
    variables = {
      FAILURE_MODE_TABLE = aws_dynamodb_table.failure_mode.name
    }
  }
}

resource "aws_lambda_function" "chaos_toggle" {
  function_name    = "selfheal-chaos-toggle"
  role             = aws_iam_role.chaos_toggle_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.chaos_toggle_zip.output_path
  source_code_hash = data.archive_file.chaos_toggle_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      FAILURE_MODE_TABLE = aws_dynamodb_table.failure_mode.name
    }
  }
}

resource "aws_apigatewayv2_api" "toy_service_api" {
  name          = "selfheal-toy-service-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "toy_service_integration" {
  api_id                 = aws_apigatewayv2_api.toy_service_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.toy_service.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "toy_service_route" {
  api_id    = aws_apigatewayv2_api.toy_service_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.toy_service_integration.id}"
}

resource "aws_apigatewayv2_integration" "chaos_toggle_integration" {
  api_id                 = aws_apigatewayv2_api.toy_service_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.chaos_toggle.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "chaos_toggle_route" {
  api_id    = aws_apigatewayv2_api.toy_service_api.id
  route_key = "POST /chaos"
  target    = "integrations/${aws_apigatewayv2_integration.chaos_toggle_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_chaos" {
  statement_id  = "AllowAPIGatewayInvokeChaos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chaos_toggle.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.toy_service_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "toy_service_stage" {
  api_id      = aws_apigatewayv2_api.toy_service_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.toy_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.toy_service_api.execution_arn}/*/*"
}

# --- Detection: CloudWatch alarm (Day 2). EventBridge now lives in the
# orchestration module, pointed at this alarm's ARN, and triggers the real
# Step Functions pipeline instead of a placeholder Lambda (Day 3). ---

resource "aws_cloudwatch_metric_alarm" "toy_service_errors" {
  alarm_name          = "selfheal-toy-service-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.toy_service_api.id
    Stage = aws_apigatewayv2_stage.toy_service_stage.name
  }
}
