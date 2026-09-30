output "state_machine_arn" {
  value = aws_sfn_state_machine.self_heal_pipeline.arn
}

output "incident_log_table_name" {
  value = aws_dynamodb_table.incident_log.name
}
