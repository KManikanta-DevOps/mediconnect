variable "name" { type = string }
data "aws_caller_identity" "me" {}

resource "aws_kms_key" "this" {
  description             = "${var.name} data key"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "Admin", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.me.account_id}:root" }, Action = "kms:*", Resource = "*" },
      { Sid = "AwsServices", Effect = "Allow", Principal = { Service = ["cloudtrail.amazonaws.com", "sns.amazonaws.com", "sqs.amazonaws.com", "logs.amazonaws.com"] }, Action = ["kms:GenerateDataKey*", "kms:Decrypt"], Resource = "*" },
    ]
  })
}
resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
output "key_arn" { value = aws_kms_key.this.arn }
output "key_id"  { value = aws_kms_key.this.key_id }
