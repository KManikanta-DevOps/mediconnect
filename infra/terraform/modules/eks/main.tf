variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "instance_types" { type = list(string) }
variable "capacity_type" { type = string }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "kms_key_arn" { type = string }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"
  cluster_name    = var.name
  cluster_version = "1.30"
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets
  cluster_endpoint_public_access = true # restrict with cluster_endpoint_public_access_cidrs in real use
  enable_irsa = true
  enable_cluster_creator_admin_permissions = true
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
  cluster_encryption_config = { provider_key_arn = var.kms_key_arn, resources = ["secrets"] }
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    aws-ebs-csi-driver = {}
  }
  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types
      capacity_type  = var.capacity_type
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.min_size
      metadata_options = { http_tokens = "required", http_put_response_hop_limit = 1 } # IMDSv2
    }
  }
}
output "cluster_name"            { value = module.eks.cluster_name }
output "oidc_provider_arn"       { value = module.eks.oidc_provider_arn }
output "oidc_issuer"             { value = replace(module.eks.cluster_oidc_issuer_url, "https://", "") }
output "node_security_group_id"  { value = module.eks.node_security_group_id }
