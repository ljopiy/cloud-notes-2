.PHONY: init plan apply destroy deploy build

init:
	@echo "🚀 Initializing Terraform..."
	cd terraform && terraform init

plan:
	@echo "📋 Planning infrastructure..."
	cd terraform && terraform plan

apply:
	@echo "🔄 Applying infrastructure..."
	cd terraform && terraform apply -auto-approve

destroy:
	@echo "🗑️  Destroying infrastructure..."
	cd terraform && terraform destroy -auto-approve

deploy: build apply
	@echo "✅ Deployment completed!"

build:
	@echo "📦 Building Docker image..."
	docker build -t cr.yandex/$(shell cd terraform && terraform output -raw container_registry_id)/cloud-notes-backend:latest -f backend/Dockerfile.prod ./backend
	docker push cr.yandex/$(shell cd terraform && terraform output -raw container_registry_id)/cloud-notes-backend:latest

output:
	@echo "📊 Outputs:"
	cd terraform && terraform output

test:
	@echo "🧪 Testing application..."
	curl -f http://$(shell cd terraform && terraform output -raw load_balancer_ip)/health

help:
	@echo "Available commands:"
	@echo "  make init     - Initialize Terraform"
	@echo "  make plan     - Plan infrastructure changes"
	@echo "  make apply    - Apply infrastructure changes"
	@echo "  make destroy  - Destroy infrastructure"
	@echo "  make build    - Build and push Docker image"
	@echo "  make deploy   - Build and deploy everything"
	@echo "  make output   - Show Terraform outputs"
	@echo "  make test     - Test application health"
