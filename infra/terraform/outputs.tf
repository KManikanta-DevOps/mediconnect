output "cluster_name"       { value = module.eks.cluster_name }
output "rds_endpoint"       { value = module.rds.endpoint }
output "reports_bucket"     { value = module.s3_reports.bucket_name }
output "reminder_queue_url" { value = module.messaging.queue_url }
output "redis_endpoint"     { value = module.redis.endpoint }
output "cognito_pool_id"    { value = module.cognito.user_pool_id }
output "cognito_client_id"  { value = module.cognito.client_id }
output "ci_role_arn"        { value = aws_iam_role.github_ci.arn }
output "irsa_role_arns" {
  value = {
    patient-records-service = module.irsa_patient_records.role_arn
    appointment-service     = module.irsa_appointment.role_arn
    notification-service    = module.irsa_notification.role_arn
  }
}
