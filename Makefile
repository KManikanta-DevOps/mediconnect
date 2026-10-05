.PHONY: up down test tf-plan
up:      ; docker compose up --build
down:    ; docker compose down -v
test:    ; for s in services/*; do (cd $$s && pip install -q -r requirements.txt && pytest -q) || exit 1; done
tf-plan: ; cd infra/terraform && terraform init && terraform workspace select -or-create dev && terraform plan -var-file=envs/dev.tfvars
