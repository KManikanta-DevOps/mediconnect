variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "allowed_sg_id" { type = string }
variable "instance_class" { type = string }
variable "multi_az" { type = bool }
variable "kms_key_arn" { type = string }
variable "backup_retention" { type = number }

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]
  }
}
resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}
resource "aws_db_parameter_group" "pg" {
  name_prefix = "${var.name}-"
  family      = "postgres16"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_statement"
    value = "ddl"
  }
}
resource "aws_db_instance" "this" {
  identifier              = var.name
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.instance_class
  allocated_storage       = 20
  max_allocated_storage   = 100
  db_name                 = "mediconnect"
  username                = "mediconnect"
  manage_master_user_password   = true # password lives in Secrets Manager, never in state/code
  master_user_secret_kms_key_id = var.kms_key_arn
  storage_encrypted       = true
  kms_key_id              = var.kms_key_arn
  multi_az                = var.multi_az
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  parameter_group_name    = aws_db_parameter_group.pg.name
  backup_retention_period = var.backup_retention
  deletion_protection     = var.multi_az
  skip_final_snapshot     = !var.multi_az
  final_snapshot_identifier = var.multi_az ? "${var.name}-final" : null
  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  auto_minor_version_upgrade      = true
  publicly_accessible             = false
}
output "endpoint"   { value = aws_db_instance.this.address }
output "secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
