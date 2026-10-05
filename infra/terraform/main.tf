# Environments are Terraform workspaces: dev / stage / prod
#   terraform workspace select -or-create dev
#   terraform apply -var-file=envs/dev.tfvars
locals {
  env  = terraform.workspace
  name = "mediconnect-${terraform.workspace}"
  services = ["auth-service", "appointment-service", "patient-records-service", "notification-service"]
}

data "aws_caller_identity" "me" {}

module "kms" {
  source = "./modules/kms"
  name   = local.name
}

module "vpc" {
  source   = "./modules/vpc"
  name     = local.name
  cidr     = var.vpc_cidr
  single_nat = local.env != "prod"
}

module "eks" {
  source          = "./modules/eks"
  name            = local.name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  instance_types  = var.node_instance_types
  capacity_type   = var.node_capacity_type
  min_size        = var.node_min
  max_size        = var.node_max
  kms_key_arn     = module.kms.key_arn
}

module "rds" {
  source             = "./modules/rds"
  name               = local.name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.database_subnets
  allowed_sg_id      = module.eks.node_security_group_id
  instance_class     = var.db_instance_class
  multi_az           = var.db_multi_az
  kms_key_arn        = module.kms.key_arn
  backup_retention   = local.env == "prod" ? 14 : 7
}

module "s3_reports" {
  source      = "./modules/s3"
  bucket_name = "${local.name}-reports-${data.aws_caller_identity.me.account_id}"
  kms_key_arn = module.kms.key_arn
}

module "messaging" {
  source      = "./modules/messaging"
  name        = local.name
  kms_key_id  = module.kms.key_id
  alert_email = var.alert_email
}

module "redis" {
  source     = "./modules/redis"
  name       = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  allowed_sg_id = module.eks.node_security_group_id
}

module "cognito" {
  source = "./modules/cognito"
  name   = local.name
}

module "ecr" {
  source       = "./modules/ecr"
  repositories = local.services
  kms_key_arn  = module.kms.key_arn
}

module "security" {
  source = "./modules/security" # CloudTrail, AWS Config, GuardDuty
  name   = local.name
  kms_key_arn = module.kms.key_arn
}

# ---- IRSA: least-privilege role per service ----
module "irsa_patient_records" {
  source            = "./modules/irsa"
  name              = "${local.name}-patient-records"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
  namespace         = "mediconnect"
  service_account   = "patient-records-service"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${module.s3_reports.bucket_arn}/*" },
      { Effect = "Allow", Action = ["kms:GenerateDataKey", "kms:Decrypt"], Resource = module.kms.key_arn },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = module.rds.secret_arn },
    ]
  })
}

module "irsa_appointment" {
  source            = "./modules/irsa"
  name              = "${local.name}-appointment"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
  namespace         = "mediconnect"
  service_account   = "appointment-service"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = module.messaging.queue_arn },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = module.rds.secret_arn },
      { Effect = "Allow", Action = ["kms:GenerateDataKey", "kms:Decrypt"], Resource = module.kms.key_arn },
    ]
  })
}

module "irsa_notification" {
  source            = "./modules/irsa"
  name              = "${local.name}-notification"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
  namespace         = "mediconnect"
  service_account   = "notification-service"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = module.messaging.queue_arn },
      { Effect = "Allow", Action = ["ses:SendEmail"], Resource = "*", Condition = { StringEquals = { "ses:FromAddress" = var.ses_sender } } },
      { Effect = "Allow", Action = ["kms:Decrypt"], Resource = module.kms.key_arn },
    ]
  })
}

# ---- GitHub Actions OIDC (no long-lived keys in CI) ----
resource "aws_iam_openid_connect_provider" "github" {
  count           = local.env == "dev" ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  url        = "https://token.actions.githubusercontent.com"
  depends_on = [aws_iam_openid_connect_provider.github]
}

resource "aws_iam_role" "github_ci" {
  name = "${local.name}-github-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_ci_ecr" {
  role = aws_iam_role.github_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"], Resource = module.ecr.repository_arns },
    ]
  })
}
