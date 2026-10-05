variable "name" { type = string }
variable "cidr" { type = string }
variable "single_nat" { type = bool }
data "aws_availability_zones" "az" { state = "available" }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"
  name    = var.name
  cidr    = var.cidr
  azs              = slice(data.aws_availability_zones.az.names, 0, 3)
  public_subnets   = [for i in range(3) : cidrsubnet(var.cidr, 8, i)]
  private_subnets  = [for i in range(3) : cidrsubnet(var.cidr, 8, i + 10)]
  database_subnets = [for i in range(3) : cidrsubnet(var.cidr, 8, i + 20)]
  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat
  enable_dns_hostnames = true
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
output "vpc_id"            { value = module.vpc.vpc_id }
output "private_subnets"   { value = module.vpc.private_subnets }
output "database_subnets"  { value = module.vpc.database_subnets }
