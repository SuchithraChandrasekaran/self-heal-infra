data "archive_file" "toy_service_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda_src.zip"
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

# Least-privilege: this role only gets basic CloudWatch Logs write access.
# No DynamoDB/other permissions until Day 2 needs them.
resource "aws_iam_role_policy_attachment" "toy_service_logs" {
  role       = aws_iam_role.toy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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
