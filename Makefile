.PHONY: help dev api web build test lint clean docker-up docker-down docker-build

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

dev: ## Run backend and frontend together
	@echo "Starting API and Web dev servers..."
	@$(MAKE) -j2 api web

api: ## Run the API dev server
	@echo "TODO: Add your API dev command (e.g., dotnet run --project src/api)"

web: ## Run the frontend dev server
	@echo "TODO: Add your frontend dev command (e.g., pnpm --dir src/web dev)"

build: ## Build everything
	@echo "TODO: Add your build commands"

test: ## Run tests
	@echo "TODO: Add your test commands"

lint: ## Lint code
	@echo "TODO: Add your lint commands"

clean: ## Clean build artifacts
	@echo "TODO: Add your clean commands"

docker-up: ## Start app + SQL Server in Docker
	docker compose up --build -d

docker-down: ## Stop Docker containers
	docker compose down

docker-build: ## Build Docker image only
	docker build -t __PROJECT__:local -f src/api/Dockerfile .
