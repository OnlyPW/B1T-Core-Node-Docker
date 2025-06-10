# B1T Core Node - Makefile
# Simplified management commands for the B1T Core Node Docker project

# =============================================================================
# Configuration
# =============================================================================

# Default values
COMPOSE_FILE := docker-compose.yml
CONTAINER_NAME := b1t-core-node
IMAGE_NAME := b1t-core-node
DATA_DIR := ./data
LOGS_DIR := ./logs

# Load environment variables if .env exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

# =============================================================================
# Help Target
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)B1T Core Node - Docker Management$(RESET)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  make setup     # Initial setup"
	@echo "  make start     # Start the node"
	@echo "  make logs      # View logs"
	@echo "  make status    # Check status"

# =============================================================================
# Setup and Installation
# =============================================================================

.PHONY: setup
setup: ## Initial setup - create directories and copy config
	@echo "$(BLUE)Setting up B1T Core Node...$(RESET)"
	@mkdir -p $(DATA_DIR)
	@mkdir -p $(LOGS_DIR)
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)Created .env file from template$(RESET)"; \
		echo "$(YELLOW)Please edit .env file with your configuration$(RESET)"; \
	else \
		echo "$(YELLOW).env file already exists$(RESET)"; \
	fi
	@echo "$(GREEN)Setup completed!$(RESET)"

.PHONY: check-env
check-env: ## Check if .env file exists and is configured
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found!$(RESET)"; \
		echo "$(YELLOW)Run 'make setup' first$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN).env file found$(RESET)"

# =============================================================================
# Docker Operations
# =============================================================================

.PHONY: build
build: check-env ## Build the Docker image
	@echo "$(BLUE)Building B1T Core Node image...$(RESET)"
	docker-compose build --no-cache
	@echo "$(GREEN)Build completed!$(RESET)"

.PHONY: start
start: check-env ## Start the B1T Core Node
	@echo "$(BLUE)Starting B1T Core Node...$(RESET)"
	docker-compose up -d
	@echo "$(GREEN)B1T Core Node started!$(RESET)"
	@echo "$(YELLOW)Use 'make logs' to view startup logs$(RESET)"

.PHONY: stop
stop: ## Stop the B1T Core Node
	@echo "$(BLUE)Stopping B1T Core Node...$(RESET)"
	docker-compose down
	@echo "$(GREEN)B1T Core Node stopped!$(RESET)"

.PHONY: restart
restart: ## Restart the B1T Core Node
	@echo "$(BLUE)Restarting B1T Core Node...$(RESET)"
	docker-compose restart
	@echo "$(GREEN)B1T Core Node restarted!$(RESET)"

.PHONY: rebuild
rebuild: ## Rebuild and restart the node
	@echo "$(BLUE)Rebuilding and restarting B1T Core Node...$(RESET)"
	make stop
	make build
	make start
	@echo "$(GREEN)Rebuild completed!$(RESET)"

# =============================================================================
# Monitoring and Logs
# =============================================================================

.PHONY: status
status: ## Show container status
	@echo "$(BLUE)B1T Core Node Status:$(RESET)"
	docker-compose ps
	@echo ""
	@if docker-compose ps | grep -q "Up"; then \
		echo "$(GREEN)Node is running$(RESET)"; \
	else \
		echo "$(RED)Node is not running$(RESET)"; \
	fi

.PHONY: logs
logs: ## Show container logs (follow mode)
	@echo "$(BLUE)Showing B1T Core Node logs (Ctrl+C to exit):$(RESET)"
	docker-compose logs -f

.PHONY: logs-tail
logs-tail: ## Show last 100 lines of logs
	@echo "$(BLUE)Last 100 lines of B1T Core Node logs:$(RESET)"
	docker-compose logs --tail=100

.PHONY: health
health: ## Check node health
	@echo "$(BLUE)Checking B1T Core Node health...$(RESET)"
	@if docker-compose exec -T b1t-core /usr/local/bin/healthcheck.sh; then \
		echo "$(GREEN)Health check passed!$(RESET)"; \
	else \
		echo "$(RED)Health check failed!$(RESET)"; \
	fi

# =============================================================================
# B1T Core Commands
# =============================================================================

.PHONY: cli
cli: ## Open B1T CLI interactive shell
	@echo "$(BLUE)Opening B1T CLI (type 'exit' to quit):$(RESET)"
	docker-compose exec b1t-core bash

.PHONY: info
info: ## Show blockchain info
	@echo "$(BLUE)Blockchain Information:$(RESET)"
	docker-compose exec -T b1t-core b1t-cli getblockchaininfo

.PHONY: network-info
network-info: ## Show network info
	@echo "$(BLUE)Network Information:$(RESET)"
	docker-compose exec -T b1t-core b1t-cli getnetworkinfo

.PHONY: peers
peers: ## Show connected peers
	@echo "$(BLUE)Connected Peers:$(RESET)"
	docker-compose exec -T b1t-core b1t-cli getpeerinfo

.PHONY: block-count
block-count: ## Show current block count
	@echo "$(BLUE)Current Block Count:$(RESET)"
	docker-compose exec -T b1t-core b1t-cli getblockcount

.PHONY: wallet-info
wallet-info: ## Show wallet info (if wallet is enabled)
	@echo "$(BLUE)Wallet Information:$(RESET)"
	docker-compose exec -T b1t-core b1t-cli getwalletinfo

# =============================================================================
# Maintenance
# =============================================================================

.PHONY: clean
clean: ## Stop and remove containers, networks, and images
	@echo "$(YELLOW)Warning: This will remove all containers, networks, and images!$(RESET)"
	@echo "$(YELLOW)Blockchain data will be preserved.$(RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v --remove-orphans; \
		docker image rm $(IMAGE_NAME) 2>/dev/null || true; \
		echo "$(GREEN)Cleanup completed!$(RESET)"; \
	else \
		echo "$(BLUE)Cleanup cancelled$(RESET)"; \
	fi

.PHONY: clean-data
clean-data: ## Remove all data (WARNING: This deletes the blockchain!)
	@echo "$(RED)WARNING: This will delete ALL blockchain data!$(RESET)"
	@echo "$(RED)This action cannot be undone!$(RESET)"
	@read -p "Type 'DELETE' to confirm: " -r; \
	if [[ $$REPLY == "DELETE" ]]; then \
		make stop; \
		rm -rf $(DATA_DIR); \
		rm -rf $(LOGS_DIR); \
		echo "$(GREEN)All data removed!$(RESET)"; \
	else \
		echo "$(BLUE)Data removal cancelled$(RESET)"; \
	fi

.PHONY: backup
backup: ## Create backup of blockchain data
	@echo "$(BLUE)Creating backup of blockchain data...$(RESET)"
	@mkdir -p ./backups
	@BACKUP_NAME="b1t-backup-$$(date +%Y%m%d-%H%M%S).tar.gz"; \
	tar -czf "./backups/$$BACKUP_NAME" -C $(DATA_DIR) . && \
	echo "$(GREEN)Backup created: ./backups/$$BACKUP_NAME$(RESET)"

.PHONY: update
update: ## Update to latest version
	@echo "$(BLUE)Updating B1T Core Node...$(RESET)"
	make backup
	make stop
	make build
	make start
	@echo "$(GREEN)Update completed!$(RESET)"

# =============================================================================
# Development and Testing
# =============================================================================

.PHONY: test-rpc
test-rpc: ## Test RPC connection
	@echo "$(BLUE)Testing RPC connection...$(RESET)"
	@if command -v curl >/dev/null 2>&1; then \
		curl -s -u "$(RPC_USER):$(RPC_PASSWORD)" \
			-H "Content-Type: application/json" \
			-d '{"jsonrpc":"1.0","id":"test","method":"getblockcount","params":[]}' \
			http://localhost:$(RPC_PORT)/ | \
			python3 -m json.tool 2>/dev/null || echo "RPC response received"; \
	else \
		echo "$(YELLOW)curl not available, using docker exec instead$(RESET)"; \
		docker-compose exec -T b1t-core b1t-cli getblockcount; \
	fi

.PHONY: shell
shell: ## Open shell in container
	@echo "$(BLUE)Opening shell in B1T Core container:$(RESET)"
	docker-compose exec b1t-core bash

# =============================================================================
# Default Target
# =============================================================================

.DEFAULT_GOAL := help