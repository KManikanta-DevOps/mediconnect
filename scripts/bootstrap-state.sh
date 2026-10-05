#!/usr/bin/env bash
# One-time: create the S3 bucket + DynamoDB table for Terraform remote state.
set -euo pipefail
BUCKET="${1:?usage: bootstrap-state.sh <unique-bucket-name>}"
REGION="${AWS_REGION:-us-east-1}"
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" $( [ "$REGION" != us-east-1 ] && echo "--create-bucket-configuration LocationConstraint=$REGION" )
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws dynamodb create-table --table-name mediconnect-tf-lock --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region "$REGION"
echo "Now set bucket = \"$BUCKET\" in infra/terraform/versions.tf"
