# MediConnect

Cloud-native patient appointment & records platform (HIPAA-aligned) on AWS: EKS microservices, Terraform, GitHub Actions + Argo CD GitOps, KMS/IRSA/WAF/CloudTrail security, Prometheus/Grafana observability.

See [docs/architecture.md](docs/architecture.md) for the diagram and [docs/security.md](docs/security.md) for the compliance mapping.

## Repo layout
| Path | What |
|---|---|
| `services/` | auth, appointment, patient-records, notification (FastAPI) + tests |
| `frontend/` | React (Vite) app, served from S3 + CloudFront in AWS |
| `infra/terraform/` | root module + modules: vpc, eks, rds, s3, kms, irsa, messaging, redis, cognito, ecr, security |
| `helm/` | one generic chart + per-env values |
| `argocd/` | AppProject + ApplicationSet |
| `.github/workflows/` | CI (test, Sonar, Checkov, Trivy, ECR push, tag bump) and Terraform plan/apply |
| `monitoring/` | Prometheus rules, Alertmanager/Slack, Grafana SLO dashboard |
| `load-test/` | k6 script |

## Quick start (Week 1, local)
```bash
docker compose up --build
open http://localhost:3000        # sign in as patient or doctor (local dev login)
make test
```

## Deploy to AWS (Weeks 2-4)
1. `scripts/bootstrap-state.sh <unique-bucket>` then put that bucket name in `infra/terraform/versions.tf`.
2. `cd infra/terraform && terraform init && terraform workspace select -or-create dev && terraform apply -var-file=envs/dev.tfvars`
3. Add GitHub secrets: `AWS_CI_ROLE_ARN`, `AWS_TF_ROLE_ARN` (+ `SONAR_TOKEN`, `SONAR_HOST_URL`, repo variable `SONAR_ENABLED=true`).
4. Fill `ACCOUNT_ID`, endpoints and Cognito IDs in `helm/environments/*/` from `terraform output`.
5. `aws eks update-kubeconfig --name mediconnect-dev && ./argocd/bootstrap.sh`
6. Install add-ons: AWS Load Balancer Controller, External Secrets (for `secretEnv`), kube-prometheus-stack.
7. Frontend: `npm run build` then sync `dist/` to an S3 bucket behind CloudFront + WAF (add these Terraform modules in Week 4).

## Known gaps / TODO (honest list)
- CloudFront + WAF + Route 53 + S3 frontend hosting Terraform modules are not written yet.
- Terraform and Helm were not applied/validated in the generation sandbox: run `terraform validate`, `helm lint`, and fix anything your versions flag.
- Local login is dev-only; wire the React app to Cognito (Amplify or `amazon-cognito-identity-js`) for AWS.
- Fine-grained doctor-patient authorization (which doctor may see which patient) is not modeled yet.
- Stage/prod Helm values are copies of dev; adjust before use.
