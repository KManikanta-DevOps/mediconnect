variable "name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_issuer" { type = string }
variable "namespace" { type = string }
variable "service_account" { type = string }
variable "policy_json" { type = string }

resource "aws_iam_role" "this" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "${var.oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
        "${var.oidc_issuer}:aud" = "sts.amazonaws.com"
      } }
    }]
  })
}
resource "aws_iam_role_policy" "this" {
  role   = aws_iam_role.this.id
  policy = var.policy_json
}
output "role_arn" { value = aws_iam_role.this.arn }
