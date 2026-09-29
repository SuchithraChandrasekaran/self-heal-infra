output "api_url" {
  description = "Public URL for the toy service health endpoint"
  value       = "${aws_apigatewayv2_stage.toy_service_stage.invoke_url}/health"
}

output "lambda_function_name" {
  value = aws_lambda_function.toy_service.function_name
}
