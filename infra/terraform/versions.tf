terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
  # Remote state: create bucket + lock table once with scripts/bootstrap-state.sh
  backend "s3" {
    bucket         = "mediconnect-tfstate-CHANGE_ME"
    key            = "mediconnect/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mediconnect-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = { Project = "mediconnect", Env = local.env, ManagedBy = "terraform" } }
}
