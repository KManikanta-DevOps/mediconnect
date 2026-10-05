variable "name" { type = string }
variable "kms_key_arn" { type = string }
data "aws_caller_identity" "me" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "audit" { bucket = "${var.name}-audit-${data.aws_caller_identity.me.account_id}" }
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "CloudTrailAcl", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.audit.arn },
      { Sid = "CloudTrailWrite", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.audit.arn}/AWSLogs/${data.aws_caller_identity.me.account_id}/*", Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } } },
    ]
  })
}
resource "aws_cloudtrail" "this" {
  name                          = var.name
  s3_bucket_name                = aws_s3_bucket.audit.id
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  kms_key_id                    = var.kms_key_arn
  depends_on                    = [aws_s3_bucket_policy.audit]
}
resource "aws_guardduty_detector" "this" {
  enable = true
  datasources {
    kubernetes {
  audit_logs {
    enable = true
  }
}
    s3_logs { enable = true }
  }
}

# AWS Config with a few HIPAA-relevant managed rules
resource "aws_iam_role" "config" {
  name = "${var.name}-config"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "config.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}
resource "aws_config_configuration_recorder" "this" {
  name     = var.name
  role_arn = aws_iam_role.config.arn
  recording_group { all_supported = true }
}
resource "aws_config_delivery_channel" "this" {
  name           = var.name
  s3_bucket_name = aws_s3_bucket.audit.id
  depends_on     = [aws_config_configuration_recorder.this]
}
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}
resource "aws_config_config_rule" "managed" {
  for_each = toset(["S3_BUCKET_PUBLIC_READ_PROHIBITED", "RDS_STORAGE_ENCRYPTED", "RDS_MULTI_AZ_SUPPORT",
                    "ENCRYPTED_VOLUMES", "CLOUD_TRAIL_ENABLED", "ROOT_ACCOUNT_MFA_ENABLED", "S3_BUCKET_SSL_REQUESTS_ONLY"])
  name = lower(replace(each.key, "_", "-"))
  source {
    owner             = "AWS"
    source_identifier = each.key
  }
  depends_on = [aws_config_configuration_recorder_status.this]
}
