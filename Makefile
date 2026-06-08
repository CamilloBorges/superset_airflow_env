# =============================================================================
# Makefile - Data Platform
# =============================================================================
# Comandos úteis para gerenciar o ambiente Docker Compose
#
# Uso:
#   make setup    - Configuração inicial completa
#   make up       - Iniciar todos os serviços
#   make down     - Parar todos os serviços
#   make logs     - Ver logs de todos os serviços
#   make clean    - Limpar todos os containers e volumes
# =============================================================================

.PHONY: help setup up down restart logs clean status secrets airflow superset hop user list-users delete-user

# Comando padrão
.DEFAULT_GOAL := help

# Cores para output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

help: ## Mostra esta mensagem de ajuda
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)  Data Platform - Comandos Make$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

setup: ## Configuração inicial completa do ambiente
	@echo "$(GREEN)Iniciando configuração do ambiente...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Copiando .env.example para .env...$(NC)"; \
		cp .env.example .env; \
		echo "$(RED)ATENÇÃO: Edite o arquivo .env com suas credenciais LDAP!$(NC)"; \
	else \
		echo "$(GREEN)Arquivo .env já existe.$(NC)"; \
	fi
	@echo "$(YELLOW)Criando diretórios necessários...$(NC)"
	@mkdir -p airflow/logs airflow/dags airflow/plugins airflow/config
	@mkdir -p superset/config superset/data
	@mkdir -p hop/config hop/projects hop/metadata
	@mkdir -p postgres/init-scripts shared/data
	@mkdir -p ldap
	@echo "$(GREEN)✓ Configuração concluída!$(NC)"
	@echo "$(YELLOW)Próximo passo: Execute 'make secrets' para gerar chaves de segurança$(NC)"

secrets: ## Gera chaves e secrets necessários
	@echo "$(GREEN)Gerando chaves de segurança...$(NC)"
	@python3 generate_secrets.py || python generate_secrets.py

up: ## Inicia todos os serviços
	@echo "$(GREEN)Iniciando serviços...$(NC)"
	docker compose up -d
	@echo "$(GREEN)✓ Serviços iniciados!$(NC)"
	@echo ""
	@echo "$(YELLOW)Acesse:$(NC)"
	@echo "  - Superset:     http://localhost:8088"
	@echo "  - Airflow:      http://localhost:8080"
	@echo "  - Hop:          http://localhost:8081"
	@echo "  - phpLDAPadmin: http://localhost:8082"
	@echo ""
	@echo "$(YELLOW)Login padrão LDAP:$(NC)"
	@echo "  - Username: admin"
	@echo "  - Password: (definido em LDAP_ADMIN_PASSWORD no .env)"

down: ## Para todos os serviços
	@echo "$(YELLOW)Parando serviços...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Serviços parados!$(NC)"

restart: down up ## Reinicia todos os serviços

logs: ## Mostra logs de todos os serviços
	docker compose logs -f

logs-airflow: ## Mostra logs do Airflow
	docker compose logs -f airflow-webserver airflow-scheduler airflow-worker

logs-superset: ## Mostra logs do Superset
	docker compose logs -f superset superset-worker superset-beat

logs-hop: ## Mostra logs do Hop
	docker compose logs -f hop-server

status: ## Mostra status de todos os serviços
	@echo "$(GREEN)Status dos serviços:$(NC)"
	@docker compose ps

ps: status ## Alias para status

clean: ## Remove todos os containers e volumes (CUIDADO!)
	@echo "$(RED)ATENÇÃO: Isso irá remover TODOS os dados!$(NC)"
	@echo "$(RED)Pressione Ctrl+C para cancelar, Enter para continuar...$(NC)"
	@read confirm
	@echo "$(YELLOW)Removendo containers e volumes...$(NC)"
	docker compose down -v
	@echo "$(GREEN)✓ Ambiente limpo!$(NC)"

reset: clean setup up ## Reseta o ambiente completamente

shell-airflow: ## Acessa shell do container Airflow
	docker exec -it airflow-webserver bash

shell-superset: ## Acessa shell do container Superset
	docker exec -it superset bash

shell-hop: ## Acessa shell do container Hop
	docker exec -it hop-server bash

shell-postgres: ## Acessa shell do PostgreSQL
	docker exec -it postgres psql -U $$POSTGRES_USER

airflow-test: ## Testa conexão com Airflow
	@curl -s http://localhost:8080/health | grep -q "healthy" && \
		echo "$(GREEN)✓ Airflow está rodando!$(NC)" || \
		echo "$(RED)✗ Airflow não está respondendo$(NC)"

superset-test: ## Testa conexão com Superset
	@curl -s http://localhost:8088/health | grep -q "OK" && \
		echo "$(GREEN)✓ Superset está rodando!$(NC)" || \
		echo "$(RED)✗ Superset não está respondendo$(NC)"

test: airflow-test superset-test ## Testa todos os serviços

update: ## Atualiza as imagens Docker
	@echo "$(YELLOW)Atualizando imagens...$(NC)"
	docker compose pull
	@echo "$(GREEN)✓ Imagens atualizadas!$(NC)"
	@echo "$(YELLOW)Execute 'make restart' para aplicar as atualizações$(NC)"

backup: ## Cria backup dos bancos de dados
	@echo "$(YELLOW)Criando backup...$(NC)"
	@mkdir -p backups
	@DATE=$$(date +%Y%m%d_%H%M%S) && \
		docker exec postgres pg_dumpall -U $$POSTGRES_USER > backups/backup_$$DATE.sql && \
		echo "$(GREEN)✓ Backup criado: backups/backup_$$DATE.sql$(NC)"

install-deps: ## Instala dependências Python no Airflow
	@echo "$(YELLOW)Qual pacote você quer instalar?$(NC)"
	@read package && \
		docker exec airflow-webserver pip install $$package && \
		echo "$(GREEN)✓ Pacote $$package instalado!$(NC)"

# =============================================================================
# Gerenciamento de Usuários LDAP
# =============================================================================

user: ## Cria novo usuário LDAP (simplificado)
	@echo "$(GREEN)Criando novo usuário LDAP...$(NC)"
	@bash scripts/create-user.sh

list-users: ## Lista todos os usuários LDAP
	@echo "$(GREEN)Usuários cadastrados no LDAP:$(NC)"
	@echo ""
	@bash scripts/list-users.sh

list-groups: ## Lista grupos e seus membros
	@echo "$(GREEN)Grupos LDAP e seus membros:$(NC)"
	@echo ""
	@bash scripts/list-groups.sh

delete-user: ## Remove um usuário LDAP
	@echo "$(YELLOW)Digite o username do usuário a ser removido:$(NC)"
	@bash scripts/delete-user.sh

test-user-login: ## Testa login de um usuário LDAP
	@bash scripts/test-user-login.sh

git-ignore: ## Verifica se há arquivos sensíveis não ignorados
	@echo "$(YELLOW)Verificando arquivos sensíveis...$(NC)"
	@if git ls-files | grep -E '\.env$$|\.env\.local|\.env\.production'; then \
		echo "$(RED)✗ ATENÇÃO: Arquivo .env está no Git!$(NC)"; \
	else \
		echo "$(GREEN)✓ Nenhum arquivo sensível detectado$(NC)"; \
	fi
