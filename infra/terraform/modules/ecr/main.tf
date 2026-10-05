variable "repositories" { type = list(string) }
variable "kms_key_arn" { type = string }

resource "aws_ecr_repository" "this" {
  for_each             = toset(var.repositories)
  name                 = "mediconnect/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
}
resource "aws_ecr_lifecycle_policy" "keep20" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "keep last 20",
    selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20 },
    action = { type = "expire" } }] })
}
output "repository_arns" { value = [for r in aws_ecr_repository.this : r.arn] }
