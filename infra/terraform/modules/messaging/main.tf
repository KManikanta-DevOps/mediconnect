variable "name" { type = string }
variable "kms_key_id" { type = string }
variable "alert_email" { type = string }

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-reminders-dlq"
  kms_master_key_id         = var.kms_key_id
  message_retention_seconds = 1209600
}
resource "aws_sqs_queue" "reminders" {
  name              = "${var.name}-reminders"
  kms_master_key_id = var.kms_key_id
  visibility_timeout_seconds = 60
  redrive_policy = jsonencode({ deadLetterTargetArn = aws_sqs_queue.dlq.arn, maxReceiveCount = 5 })
}
resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = var.kms_key_id
}
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.name}-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
output "queue_arn"  { value = aws_sqs_queue.reminders.arn }
output "queue_url"  { value = aws_sqs_queue.reminders.url }
output "alerts_topic_arn" { value = aws_sns_topic.alerts.arn }
