output "api_url" {
  description = "Public URL for the toy service health endpoint"
  value       = "${trimsuffix(aws_apigatewayv2_stage.toy_service_stage.invoke_url, "/")}/health"
}

output "lambda_function_name" {
  value = aws_lambda_function.toy_service.function_name
}

output "chaos_toggle_url" {
  description = "POST here to flip the chaos flag between healthy and degraded"
  value       = "${trimsuffix(aws_apigatewayv2_stage.toy_service_stage.invoke_url, "/")}/chaos"
}

output "alarm_arn" {
  description = "ARN of the toy service error alarm, for EventBridge to watch"
  value       = aws_cloudwatch_metric_alarm.toy_service_errors.arn
}

output "failure_mode_table_name" {
  value = aws_dynamodb_table.failure_mode.name
}

output "failure_mode_table_arn" {
  value = aws_dynamodb_table.failure_mode.arn
}
