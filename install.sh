#!/bin/bash
#
# install.sh - Instalação Automatizada - Plataforma de Dados Enterprise
# ========================================================================
#
# Instala e configura:
#   - Docker e Docker Compose
#   - Cloudflare Tunnel
#   - Apache Superset 6.1.0
#   - Apache Airflow 2.8.0
#   - Apache Hop 2.7.0
#   - PostgreSQL 15 + Redis 7
#   - Nginx reverse proxy
#
# Uso:
#   ./install.sh
#
# Pré-requisitos:
#   - Ubuntu 24.04 ou 22.04
#   - Usuário com sudo
#   - Arquivo .env configurado com credenciais Azure
#   - Token Cloudflare Tunnel pronto
#
# ========================================================================

set -e  # Exit on error

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Símbolos
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
INFO="${BLUE}ℹ${NC}"

# ========================================================================
# FUNÇÕES AUXILIARES
# ========================================================================

log_info() {
    echo -e "${INFO} $1"
}

log_success() {
    echo -e "${CHECK} $1"
}

log_error() {
    echo -e "${CROSS} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

check_ubuntu() {
    if [ ! -f /etc/os-release ]; then
        log_error "Sistema operacional não identificado"
        exit 1
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "Este script é para Ubuntu. Detectado: $ID"
        exit 1
    fi
    
    if [[ ! "$VERSION_ID" =~ ^(24.04|22.04|20.04)$ ]]; then
        log_error "Versão do Ubuntu não suportada: $VERSION_ID"
        log_info "Versões suportadas: 24.04, 22.04, 20.04"
        exit 1
    fi
    
    log_success "Ubuntu $VERSION_ID detectado"
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_error "Este script precisa de permissões sudo"
        log_info "Execute: sudo -v"
        exit 1
    fi
    log_success "Permissões sudo verificadas"
}

check_env_file() {
    if [ ! -f .env ]; then
        log_error "Arquivo .env não encontrado"
        log_info "Execute: cp .env.example .env"
        log_info "Depois edite .env com suas credenciais Azure"
        exit 1
    fi
    
    # Verificar se variáveis Azure estão configuradas
    source .env
    
    if [ -z "$AZURE_TENANT_ID" ] || [ "$AZURE_TENANT_ID" == "<OBTER_DO_AZURE_PORTAL>" ]; then
        log_error "AZURE_TENANT_ID não configurado no .env"
        exit 1
    fi
    
    if [ -z "$AZURE_SUPERSET_CLIENT_ID" ] || [ "$AZURE_SUPERSET_CLIENT_ID" == "<OBTER_DO_AZURE_PORTAL>" ]; then
        log_error "AZURE_SUPERSET_CLIENT_ID não configurado no .env"
        exit 1
    fi
    
    if [ -z "$AZURE_SUPERSET_CLIENT_SECRET" ] || [ "$AZURE_SUPERSET_CLIENT_SECRET" == "<OBTER_DO_AZURE_PORTAL>" ]; then
        log_error "AZURE_SUPERSET_CLIENT_SECRET não configurado no .env"
        exit 1
    fi
    
    if [ -z "$AZURE_AIRFLOW_CLIENT_ID" ] || [ "$AZURE_AIRFLOW_CLIENT_ID" == "<OBTER_DO_AZURE_PORTAL>" ]; then
        log_error "AZURE_AIRFLOW_CLIENT_ID não configurado no .env"
        exit 1
    fi
    
    if [ -z "$AZURE_AIRFLOW_CLIENT_SECRET" ] || [ "$AZURE_AIRFLOW_CLIENT_SECRET" == "<OBTER_DO_AZURE_PORTAL>" ]; then
        log_error "AZURE_AIRFLOW_CLIENT_SECRET não configurado no .env"
        exit 1
    fi
    
    log_success "Arquivo .env configurado corretamente"
}

# ========================================================================
# INSTALAÇÃO
# ========================================================================

install_docker() {
    log_step "PASSO 1: Instalando Docker"
    
    if command -v docker &> /dev/null; then
        log_info "Docker já instalado: $(docker --version)"
        return
    fi
    
    log_info "Atualizando repositórios..."
    sudo apt-get update -qq
    
    log_info "Instalando dependências..."
    sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
    
    log_info "Adicionando chave GPG do Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    log_info "Adicionando repositório Docker..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log_info "Instalando Docker Engine..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_info "Adicionando usuário ao grupo docker..."
    sudo usermod -aG docker $USER
    
    log_success "Docker instalado: $(docker --version)"
    log_info "IMPORTANTE: Será necessário fazer logout/login para usar docker sem sudo"
}

install_cloudflare_tunnel() {
    log_step "PASSO 2: Instalando Cloudflare Tunnel"
    
    if command -v cloudflared &> /dev/null; then
        log_info "Cloudflare Tunnel já instalado: $(cloudflared --version)"
        return
    fi
    
    log_info "Baixando cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    
    log_info "Instalando cloudflared..."
    sudo dpkg -i cloudflared-linux-amd64.deb
    
    log_info "Limpando arquivo de instalação..."
    rm -f cloudflared-linux-amd64.deb
    
    log_success "Cloudflare Tunnel instalado"
    
    # Configurar tunnel
    echo ""
    log_info "Configure o Cloudflare Tunnel agora:"
    echo -e "${YELLOW}1. Acesse https://one.dash.cloudflare.com/${NC}"
    echo -e "${YELLOW}2. Crie um Tunnel${NC}"
    echo -e "${YELLOW}3. Copie o token de instalação${NC}"
    echo ""
    read -p "Cole o token do Cloudflare Tunnel: " CLOUDFLARE_TOKEN
    
    if [ -z "$CLOUDFLARE_TOKEN" ]; then
        log_error "Token não fornecido. Você pode configurar depois com:"
        log_info "sudo cloudflared service install <TOKEN>"
        return
    fi
    
    log_info "Instalando serviço do tunnel..."
    sudo cloudflared service install $CLOUDFLARE_TOKEN
    
    log_info "Iniciando cloudflared..."
    sudo systemctl start cloudflared
    sudo systemctl enable cloudflared
    
    log_success "Cloudflare Tunnel configurado e ativo"
}

build_superset_image() {
    log_step "PASSO 3: Build da Imagem Superset"
    
    log_info "Construindo imagem customizada do Superset..."
    docker compose build superset-init
    
    log_success "Imagem superset-custom:latest criada"
}

start_infrastructure() {
    log_step "PASSO 4: Iniciando Infraestrutura Base"
    
    log_info "Iniciando PostgreSQL e Redis..."
    docker compose up -d postgres redis
    
    log_info "Aguardando PostgreSQL ficar healthy (30s)..."
    sleep 30
    
    # Verificar se PostgreSQL está saudável
    if ! docker compose ps postgres | grep -q "healthy"; then
        log_error "PostgreSQL não está healthy"
        log_info "Verifique logs: docker compose logs postgres"
        exit 1
    fi
    
    log_success "PostgreSQL e Redis iniciados"
}

initialize_databases() {
    log_step "PASSO 5: Inicializando Bancos de Dados"
    
    log_info "Executando migrations do Airflow e Superset..."
    docker compose up -d airflow-init superset-init
    
    log_info "Aguardando migrations completarem (60s)..."
    sleep 60
    
    # Verificar se init containers completaram
    AIRFLOW_INIT_EXIT=$(docker compose ps airflow-init --format json | grep -o '"ExitCode":[0-9]*' | cut -d':' -f2)
    SUPERSET_INIT_EXIT=$(docker compose ps superset-init --format json | grep -o '"ExitCode":[0-9]*' | cut -d':' -f2)
    
    if [ "$AIRFLOW_INIT_EXIT" != "0" ]; then
        log_error "Airflow init falhou"
        log_info "Logs: docker compose logs airflow-init"
    else
        log_success "Airflow database inicializado"
    fi
    
    if [ "$SUPERSET_INIT_EXIT" != "0" ]; then
        log_error "Superset init falhou"
        log_info "Logs: docker compose logs superset-init"
    else
        log_success "Superset database inicializado"
    fi
}

start_all_services() {
    log_step "PASSO 6: Iniciando Todos os Serviços"
    
    log_info "Iniciando Airflow, Superset, Hop e Nginx..."
    docker compose up -d
    
    log_info "Aguardando serviços ficarem healthy (30s)..."
    sleep 30
    
    log_success "Todos os serviços iniciados"
}

show_status() {
    log_step "STATUS DOS SERVIÇOS"
    
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
}

show_completion_message() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${CYAN}Acesse as aplicações:${NC}"
    echo -e "  • Superset: ${BLUE}https://$PUBLIC_DOMAIN${NC}"
    echo -e "  • Airflow:  ${BLUE}https://airflow.$PUBLIC_DOMAIN${NC}"
    echo -e "  • Hop:      ${BLUE}https://hop.$PUBLIC_DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}Próximos passos:${NC}"
    echo "  1. Configure rotas do Cloudflare Tunnel:"
    echo "     - bi.$PUBLIC_DOMAIN → nginx:80"
    echo "     - airflow.$PUBLIC_DOMAIN → nginx:8080"
    echo "     - hop.$PUBLIC_DOMAIN → nginx:8081"
    echo ""
    echo "  2. Acesse https://$PUBLIC_DOMAIN e faça login com Azure AD"
    echo ""
    echo "  3. Primeiro usuário será criado automaticamente como Gamma"
    echo "     Admin deve elevar permissões via interface web"
    echo ""
    echo -e "${CYAN}Comandos úteis:${NC}"
    echo "  • Ver logs:     docker compose logs -f <serviço>"
    echo "  • Status:       docker compose ps"
    echo "  • Restart:      docker compose restart <serviço>"
    echo "  • Parar tudo:   docker compose down"
    echo ""
    echo -e "${YELLOW}Documentação completa: INSTALL.md${NC}"
    echo ""
}

# ========================================================================
# MAIN
# ========================================================================

main() {
    clear
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Plataforma de Dados Enterprise${NC}"
    echo -e "${BLUE}  Instalação Automatizada${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Pré-requisitos
    log_step "VERIFICANDO PRÉ-REQUISITOS"
    check_ubuntu
    check_sudo
    check_env_file
    
    # Carregar variáveis do .env
    source .env
    
    # Instalação
    install_docker
    install_cloudflare_tunnel
    build_superset_image
    start_infrastructure
    initialize_databases
    start_all_services
    
    # Status
    show_status
    
    # Mensagem final
    show_completion_message
    
    # Aviso sobre reinicialização
    echo -e "${YELLOW}ATENÇÃO:${NC}"
    echo "  Após este script, faça logout/login para usar docker sem sudo"
    echo "  Ou execute: newgrp docker"
    echo ""
}

# Executar
main "$@"
