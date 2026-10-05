# Security & compliance mapping (HIPAA-style)

> Portfolio project: "HIPAA-aligned", not certified. A real deployment also needs a signed BAA with AWS and only BAA-eligible services.

| Control | Implementation |
|---|---|
| Encryption at rest | KMS CMK (rotation on) for RDS, S3, SQS, SNS, ECR, EKS secrets, Redis |
| Encryption in transit | ALB/CloudFront TLS, `rds.force_ssl`, Redis in-transit encryption, S3 TLS-only bucket policy |
| Access control | Cognito JWT + role checks, IRSA per service (least privilege), no static AWS keys, GitHub OIDC for CI |
| Network isolation | Private subnets for EKS, DB in isolated subnets, SG-to-SG rules, Kubernetes NetworkPolicies |
| Audit | CloudTrail (multi-region, log validation), VPC flow logs, EKS audit logs, app audit log lines |
| Detection | GuardDuty (EKS + S3), AWS Config rules, Trivy / Checkov / SonarQube gates |
| Secrets | RDS master password managed by Secrets Manager; never in Terraform code or git |
| Recovery | Multi-AZ RDS (prod), automated backups, S3 versioning, DR runbook |

## Documented Checkov skips
See `.checkov.yaml`; add a one-line justification for each skip here.
