#!/bin/bash
# install.sh - Script de Instalação Automatizada Completa
# ===========================================================
# Instala e configura toda a plataforma de dados do zero
#
# Uso:
#   ./install.sh                          # Modo interativo
#   ./install.sh --auto                   # Modo totalmente automático
#   ./install.sh --config install.config  # Usando arquivo de configuração
#   ./install.sh --help                   # Ajuda
#
# ===========================================================

set -e  # Exit on error

# =============================================================================
# CORES E FORMATAÇÃO
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Símbolos
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"
ROCKET="${PURPLE}🚀${NC}"

# =============================================================================
# VARIÁVEIS GLOBAIS
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"
CONFIG_FILE=""
INSTALL_MODE="interactive"
AUTO_MODE=false

# Valores padrão
PUBLIC_DOMAIN="bi.bomgado.com.br"
TIMEZONE="America/Sao_Paulo"
INSTALL_DOCKER="yes"
CONFIGURE_DOCKER_PERMISSIONS="yes"
SETUP_CLOUDFLARE="yes"
CLOUDFLARE_TUNNEL_TOKEN=""
AUTO_GENERATE_SECRETS="yes"
SETUP_SSL="skip"
SETUP_AZURE_SSO="no"
RUN_TESTS="yes"
STARTUP_WAIT_TIME=120
CREATE_BACKUP="no"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    log "=== $1 ==="
}

print_step() {
    echo -e "${CYAN}${ARROW} $1${NC}"
    log "STEP: $1"
}

print_success() {
    echo -e "${CHECK} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${CROSS} $1" >&2
    log "ERROR: $1"
}

print_warning() {
    echo -e "${WARN} $1"
    log "WARNING: $1"
}

print_info() {
    echo -e "${INFO} $1"
    log "INFO: $1"
}

confirm() {
    if [ "$AUTO_MODE" = true ]; then
        return 0
    fi
    
    local message="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        read -p "$message (Y/n): " -n 1 -r
    else
        read -p "$message (y/N): " -n 1 -r
    fi
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Não execute este script como root!"
        print_info "Execute como usuário normal. O script pedirá sudo quando necessário."
        exit 1
    fi
}

check_os() {
    print_step "Detectando sistema operacional..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_success "Sistema detectado: $NAME $VERSION_ID"
    else
        print_error "Sistema operacional não suportado!"
        exit 1
    fi
    
    if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
        print_warning "Este script foi testado em Ubuntu/Debian"
        if ! confirm "Deseja continuar mesmo assim?"; then
            exit 1
        fi
    fi
}

# =============================================================================
# FUNÇÕES DE CONFIGURAÇÃO
# =============================================================================

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_step "Carregando configuração de $CONFIG_FILE..."
        
        # Source do arquivo de configuração
        set -a  # Auto export variables
        source "$CONFIG_FILE"
        set +a
        
        print_success "Configuração carregada!"
    else
        print_warning "Arquivo de configuração não encontrado: $CONFIG_FILE"
        print_info "Usando valores padrão e modo interativo"
    fi
}

create_config_interactive() {
    print_header "Configuração Interativa"
    
    echo -e "${CYAN}Vamos configurar sua instalação...${NC}"
    echo ""
    
    # Domínio
    read -p "Domínio público (ex: bi.bomgado.com.br): " -i "$PUBLIC_DOMAIN" -e PUBLIC_DOMAIN
    
    # Cloudflare
    if confirm "Configurar Cloudflare Tunnel?" "y"; then
        SETUP_CLOUDFLARE="yes"
        echo ""
        print_info "Para obter o token:"
        echo "  1. Acesse https://dash.cloudflare.com"
        echo "  2. Zero Trust → Tunnels → Create tunnel"
        echo "  3. Copie o token"
        echo ""
        read -p "Token do Cloudflare Tunnel (deixe vazio para configurar depois): " CLOUDFLARE_TUNNEL_TOKEN
    else
        SETUP_CLOUDFLARE="no"
    fi
    
    # Azure SSO
    if confirm "Configurar Azure Entra SSO?"; then
        SETUP_AZURE_SSO="yes"
        read -p "Azure Tenant ID: " AZURE_TENANT_ID
        read -p "Superset Client ID: " AZURE_SUPERSET_CLIENT_ID
        read -sp "Superset Client Secret: " AZURE_SUPERSET_CLIENT_SECRET
        echo ""
        read -p "Airflow Client ID: " AZURE_AIRFLOW_CLIENT_ID
        read -sp "Airflow Client Secret: " AZURE_AIRFLOW_CLIENT_SECRET
        echo ""
    else
        SETUP_AZURE_SSO="no"
    fi
    
    echo ""
    print_success "Configuração completa!"
}

# =============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS
# =============================================================================

install_dependencies() {
    print_header "Instalando Dependências do Sistema"
    
    print_step "Atualizando lista de pacotes..."
    sudo apt update -qq
    
    print_step "Instalando ferramentas essenciais..."
    sudo apt install -y \
        curl \
        wget \
        git \
        vim \
        nano \
        htop \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release \
        python3 \
        python3-pip \
        jq \
        > /dev/null 2>&1
    
    print_success "Dependências instaladas!"
}

configure_timezone() {
    print_header "Configurando Timezone"
    
    print_step "Configurando timezone para $TIMEZONE..."
    sudo timedatectl set-timezone "$TIMEZONE"
    
    local current_tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
    print_success "Timezone configurado: $current_tz"
}

# =============================================================================
# INSTALAÇÃO DO DOCKER
# =============================================================================

install_docker() {
    print_header "Instalando Docker"
    
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version)
        print_success "Docker já instalado: $docker_version"
        return 0
    fi
    
    print_step "Removendo versões antigas..."
    sudo apt remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true
    
    print_step "Adicionando repositório oficial do Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_step "Instalando Docker Engine..."
    sudo apt update -qq
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    
    print_step "Habilitando Docker no boot..."
    sudo systemctl enable docker
    sudo systemctl enable containerd
    
    local docker_version=$(docker --version)
    local compose_version=$(docker compose version)
    
    print_success "Docker instalado: $docker_version"
    print_success "Docker Compose instalado: $compose_version"
}

configure_docker_permissions() {
    print_header "Configurando Permissões Docker"
    
    print_step "Adicionando usuário ao grupo docker..."
    sudo usermod -aG docker $USER
    
    print_success "Usuário $USER adicionado ao grupo docker"
    print_warning "Você precisará fazer logout/login para aplicar as permissões"
    print_info "Ou execute: newgrp docker"
}

# =============================================================================
# GERAÇÃO DE SECRETS
# =============================================================================

generate_secrets() {
    print_header "Gerando Secrets de Segurança"
    
    print_step "Gerando Postgres password..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    print_step "Gerando Redis password..."
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    print_step "Gerando Airflow Fernet Key..."
    AIRFLOW__CORE__FERNET_KEY=$(docker run --rm python:3.11-slim sh -c "pip install -q cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'")
    
    print_step "Gerando Airflow Webserver Secret Key..."
    AIRFLOW__WEBSERVER__SECRET_KEY=$(openssl rand -base64 50 | tr -d "=+/")
    
    print_step "Gerando Superset Secret Key..."
    SUPERSET_SECRET_KEY=$(openssl rand -base64 50 | tr -d "=+/")
    
    print_success "Todos os secrets gerados!"
}

create_env_file() {
    print_header "Criando Arquivo .env"
    
    if [ -f ".env" ]; then
        if ! confirm "Arquivo .env já existe. Sobrescrever?"; then
            print_warning "Mantendo .env existente"
            return 0
        fi
        
        if [ "$CREATE_BACKUP" = "yes" ]; then
            local backup_file=".env.backup.$(date +%Y%m%d_%H%M%S)"
            cp .env "$backup_file"
            print_info "Backup criado: $backup_file"
        fi
    fi
    
    print_step "Criando .env a partir do template..."
    cp .env.example .env
    
    print_step "Atualizando valores..."
    
    # Substituir valores no .env
    sed -i "s|^PUBLIC_DOMAIN=.*|PUBLIC_DOMAIN=$PUBLIC_DOMAIN|" .env
    sed -i "s|^TIMEZONE=.*|TIMEZONE=$TIMEZONE|" .env
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env
    sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|" .env
    sed -i "s|^AIRFLOW__CORE__FERNET_KEY=.*|AIRFLOW__CORE__FERNET_KEY=$AIRFLOW__CORE__FERNET_KEY|" .env
    sed -i "s|^AIRFLOW__WEBSERVER__SECRET_KEY=.*|AIRFLOW__WEBSERVER__SECRET_KEY=$AIRFLOW__WEBSERVER__SECRET_KEY|" .env
    sed -i "s|^SUPERSET_SECRET_KEY=.*|SUPERSET_SECRET_KEY=$SUPERSET_SECRET_KEY|" .env
    
    # Azure SSO (se configurado)
    if [ "$SETUP_AZURE_SSO" = "yes" ]; then
        sed -i "s|^# AZURE_TENANT_ID=.*|AZURE_TENANT_ID=$AZURE_TENANT_ID|" .env
        sed -i "s|^# AZURE_SUPERSET_CLIENT_ID=.*|AZURE_SUPERSET_CLIENT_ID=$AZURE_SUPERSET_CLIENT_ID|" .env
        sed -i "s|^# AZURE_SUPERSET_CLIENT_SECRET=.*|AZURE_SUPERSET_CLIENT_SECRET=$AZURE_SUPERSET_CLIENT_SECRET|" .env
        sed -i "s|^# AZURE_AIRFLOW_CLIENT_ID=.*|AZURE_AIRFLOW_CLIENT_ID=$AZURE_AIRFLOW_CLIENT_ID|" .env
        sed -i "s|^# AZURE_AIRFLOW_CLIENT_SECRET=.*|AZURE_AIRFLOW_CLIENT_SECRET=$AZURE_AIRFLOW_CLIENT_SECRET|" .env
    fi
    
    print_success "Arquivo .env criado e configurado!"
}

# =============================================================================
# CLOUDFLARE TUNNEL
# =============================================================================

setup_cloudflare_tunnel() {
    print_header "Configurando Cloudflare Tunnel"
    
    # Verificar se cloudflared está instalado
    if ! command -v cloudflared &> /dev/null; then
        print_step "Instalando cloudflared..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
        print_success "cloudflared instalado!"
    else
        print_success "cloudflared já instalado: $(cloudflared --version)"
    fi
    
    # Verificar se tunnel já está rodando
    if sudo systemctl is-active --quiet cloudflared; then
        print_warning "Cloudflare Tunnel já está rodando!"
        if ! confirm "Deseja reconfigurar?"; then
            return 0
        fi
        sudo systemctl stop cloudflared
        sudo cloudflared service uninstall 2>/dev/null || true
    fi
    
    # Token
    if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
        echo ""
        print_info "Para obter o token do Cloudflare Tunnel:"
        echo "  1. Acesse: https://dash.cloudflare.com"
        echo "  2. Zero Trust → Tunnels → Create tunnel"
        echo "  3. Nome: bi-bomgado-data-platform"
        echo "  4. Copie o token"
        echo ""
        echo "  Configure Public Hostnames:"
        echo "    - bi.bomgado.com.br → HTTP → localhost:80"
        echo "    - airflow.bomgado.com.br → HTTP → localhost:8080"
        echo "    - hop.bomgado.com.br → HTTP → localhost:8081"
        echo ""
        read -p "Cole o token aqui: " CLOUDFLARE_TUNNEL_TOKEN
    fi
    
    if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
        print_error "Token não fornecido. Pulando configuração do Cloudflare Tunnel."
        return 1
    fi
    
    print_step "Instalando tunnel service..."
    sudo cloudflared service install "$CLOUDFLARE_TUNNEL_TOKEN"
    
    print_step "Iniciando serviço..."
    sudo systemctl start cloudflared
    sudo systemctl enable cloudflared
    
    sleep 5
    
    if sudo systemctl is-active --quiet cloudflared; then
        print_success "Cloudflare Tunnel configurado e rodando!"
        print_info "Verifique logs com: sudo journalctl -u cloudflared -f"
    else
        print_error "Falha ao iniciar Cloudflare Tunnel"
        print_info "Verifique logs com: sudo journalctl -u cloudflared -n 50"
        return 1
    fi
}

# =============================================================================
# ESTRUTURA DE DIRETÓRIOS E PERMISSÕES
# =============================================================================

create_directory_structure() {
    print_header "Criando Estrutura de Diretórios"
    
    print_step "Criando diretórios..."
    mkdir -p airflow/{logs,dags,plugins,config}
    mkdir -p superset/{config,data}
    mkdir -p hop/{config,projects,metadata}
    mkdir -p postgres/init-scripts
    mkdir -p shared/data
    mkdir -p nginx
    
    print_success "Estrutura de diretórios criada!"
}

configure_permissions() {
    print_header "Configurando Permissões"
    
    print_step "Ajustando permissões básicas..."
    chmod -R 755 airflow superset hop postgres shared nginx
    chmod -R 777 airflow/logs
    
    print_step "Configurando permissões do Airflow (UID 50000)..."
    sudo chown -R 50000:0 airflow/
    
    print_step "Tornando scripts executáveis..."
    chmod +x *.sh 2>/dev/null || true
    chmod +x postgres/init-scripts/*.sh 2>/dev/null || true
    
    print_success "Permissões configuradas!"
}

# =============================================================================
# CONFIGURAÇÃO DE SSO
# =============================================================================

setup_azure_sso_config() {
    print_header "Configurando Azure Entra SSO"
    
    # Criar webserver_config.py para Airflow
    print_step "Criando airflow/config/webserver_config.py..."
    cat > airflow/config/webserver_config.py << 'AIRFLOW_EOF'
from flask_appbuilder.security.manager import AUTH_OAUTH
import os

AUTH_TYPE = AUTH_OAUTH

OAUTH_PROVIDERS = [
    {
        'name': 'azure',
        'icon': 'fa-windows',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.getenv('AZURE_AIRFLOW_CLIENT_ID'),
            'client_secret': os.getenv('AZURE_AIRFLOW_CLIENT_SECRET'),
            'api_base_url': 'https://graph.microsoft.com/v1.0/',
            'client_kwargs': {
                'scope': 'openid email profile User.Read'
            },
            'access_token_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token",
            'authorize_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/authorize",
            'server_metadata_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/v2.0/.well-known/openid-configuration",
        }
    }
]

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"

from airflow.www.security import AirflowSecurityManager

class AzureSecurityManager(AirflowSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'azure':
            import requests
            access_token = response.get('access_token')
            me = requests.get(
                'https://graph.microsoft.com/v1.0/me',
                headers={'Authorization': f'Bearer {access_token}'}
            ).json()
            return {
                'username': me.get('userPrincipalName', '').split('@')[0],
                'name': me.get('displayName', ''),
                'email': me.get('mail') or me.get('userPrincipalName'),
                'first_name': me.get('givenName', ''),
                'last_name': me.get('surname', ''),
                'role_keys': ['Viewer'],
            }
        return {}

SECURITY_MANAGER_CLASS = AzureSecurityManager
AIRFLOW_EOF
    
    # Criar superset_config.py para Superset
    print_step "Criando superset/config/superset_config.py..."
    cat > superset/config/superset_config.py << 'SUPERSET_EOF'
from flask_appbuilder.security.manager import AUTH_OAUTH
import os

AUTH_TYPE = AUTH_OAUTH

OAUTH_PROVIDERS = [
    {
        'name': 'azure',
        'icon': 'fa-windows',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.getenv('AZURE_SUPERSET_CLIENT_ID'),
            'client_secret': os.getenv('AZURE_SUPERSET_CLIENT_SECRET'),
            'api_base_url': 'https://graph.microsoft.com/v1.0/',
            'client_kwargs': {
                'scope': 'openid email profile User.Read'
            },
            'access_token_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token",
            'authorize_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/authorize",
            'server_metadata_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/v2.0/.well-known/openid-configuration",
        }
    }
]

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"

from superset.security import SupersetSecurityManager

class AzureSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'azure':
            import requests
            access_token = response.get('access_token')
            me = requests.get(
                'https://graph.microsoft.com/v1.0/me',
                headers={'Authorization': f'Bearer {access_token}'}
            ).json()
            return {
                'username': me.get('userPrincipalName', '').split('@')[0],
                'name': me.get('displayName', ''),
                'email': me.get('mail') or me.get('userPrincipalName'),
                'first_name': me.get('givenName', ''),
                'last_name': me.get('surname', ''),
            }
        return {}

CUSTOM_SECURITY_MANAGER = AzureSecurityManager
SUPERSET_EOF
    
    print_success "Arquivos de configuração SSO criados!"
}

# =============================================================================
# DEPLOY DA PLATAFORMA
# =============================================================================

deploy_platform() {
    print_header "Deploy da Plataforma"
    
    print_step "Baixando imagens Docker (pode levar alguns minutos)..."
    docker compose pull
    
    print_step "Iniciando containers..."
    docker compose up -d
    
    print_info "Aguardando containers inicializarem ($STARTUP_WAIT_TIME segundos)..."
    
    # Progress bar
    for i in $(seq 1 $STARTUP_WAIT_TIME); do
        echo -ne "\rProgresso: [$i/$STARTUP_WAIT_TIME] "
        printf '█%.0s' $(seq 1 $((i * 50 / STARTUP_WAIT_TIME)))
        sleep 1
    done
    echo ""
    
    print_success "Containers iniciados!"
}

# =============================================================================
# TESTES E VERIFICAÇÃO
# =============================================================================

run_tests() {
    print_header "Executando Testes"
    
    local failed=0
    
    # Teste 1: Containers rodando
    print_step "Verificando status dos containers..."
    local running=$(docker compose ps --format json | jq -r '.State' | grep -c "running" || echo "0")
    local total=$(docker compose ps --format json | wc -l)
    
    if [ "$running" -eq "$total" ]; then
        print_success "Todos os $total containers estão rodando"
    else
        print_warning "$running de $total containers rodando"
        docker compose ps
        ((failed++))
    fi
    
    # Teste 2: Teste HTTP local
    print_step "Testando Superset (localhost:80)..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200\|302"; then
        print_success "Superset respondendo"
    else
        print_error "Superset não está respondendo"
        ((failed++))
    fi
    
    print_step "Testando Airflow (localhost:8080)..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
        print_success "Airflow respondendo"
    else
        print_error "Airflow não está respondendo"
        ((failed++))
    fi
    
    print_step "Testando Hop (localhost:8081)..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|302"; then
        print_success "Hop respondendo"
    else
        print_error "Hop não está respondendo"
        ((failed++))
    fi
    
    # Teste 3: Cloudflare Tunnel
    if [ "$SETUP_CLOUDFLARE" = "yes" ]; then
        print_step "Verificando Cloudflare Tunnel..."
        if sudo systemctl is-active --quiet cloudflared; then
            print_success "Cloudflare Tunnel ativo"
        else
            print_error "Cloudflare Tunnel não está ativo"
            ((failed++))
        fi
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        print_success "Todos os testes passaram! ✓"
        return 0
    else
        print_warning "$failed teste(s) falharam"
        return 1
    fi
}

# =============================================================================
# RESUMO E CONCLUSÃO
# =============================================================================

print_summary() {
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}📊 URLs de Acesso:${NC}"
    echo ""
    
    if [ "$SETUP_CLOUDFLARE" = "yes" ]; then
        echo -e "  ${ROCKET} ${WHITE}Superset BI:${NC}    https://bi.bomgado.com.br"
        echo -e "  ${ROCKET} ${WHITE}Airflow:${NC}        https://airflow.bomgado.com.br"
        echo -e "  ${ROCKET} ${WHITE}Hop:${NC}            https://hop.bomgado.com.br"
    else
        echo -e "  ${ROCKET} ${WHITE}Superset BI:${NC}    http://localhost:80"
        echo -e "  ${ROCKET} ${WHITE}Airflow:${NC}        http://localhost:8080"
        echo -e "  ${ROCKET} ${WHITE}Hop:${NC}            http://localhost:8081"
    fi
    
    echo ""
    echo -e "${CYAN}🔐 Credenciais Padrão:${NC}"
    echo ""
    echo -e "  ${WHITE}Usuário:${NC}   admin"
    echo -e "  ${WHITE}Senha:${NC}     admin123"
    echo ""
    echo -e "  ${WARN} ${YELLOW}Altere as senhas após o primeiro login!${NC}"
    echo ""
    
    echo -e "${CYAN}📝 Comandos Úteis:${NC}"
    echo ""
    echo -e "  ${WHITE}Status:${NC}              docker compose ps"
    echo -e "  ${WHITE}Logs:${NC}                docker compose logs -f"
    echo -e "  ${WHITE}Reiniciar:${NC}           docker compose restart"
    echo -e "  ${WHITE}Parar:${NC}               docker compose down"
    echo -e "  ${WHITE}Iniciar:${NC}             docker compose up -d"
    
    if [ "$SETUP_CLOUDFLARE" = "yes" ]; then
        echo -e "  ${WHITE}Cloudflare Tunnel:${NC}   sudo systemctl status cloudflared"
    fi
    
    echo ""
    echo -e "${CYAN}📚 Documentação:${NC}"
    echo ""
    echo -e "  ${WHITE}README.md${NC}                 - Visão geral"
    echo -e "  ${WHITE}TROUBLESHOOTING.md${NC}        - Solução de problemas"
    echo -e "  ${WHITE}AZURE_ENTRA_SSO.md${NC}        - Configurar SSO"
    echo -e "  ${WHITE}SECURITY_BEST_PRACTICES.md${NC} - Boas práticas"
    echo ""
    
    echo -e "${CYAN}📊 Logs da Instalação:${NC}"
    echo -e "  $LOG_FILE"
    echo ""
    
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
}

# =============================================================================
# FUNÇÃO MAIN
# =============================================================================

show_help() {
    cat << EOF
Uso: ./install.sh [OPÇÕES]

OPÇÕES:
    --auto                    Modo totalmente automático (sem confirmações)
    --config FILE             Usar arquivo de configuração específico
    --help                    Exibir esta ajuda
    
EXEMPLOS:
    ./install.sh                          # Modo interativo
    ./install.sh --auto                   # Totalmente automático
    ./install.sh --config install.config  # Com arquivo de configuração
    
ARQUIVO DE CONFIGURAÇÃO:
    Copie install.config.example para install.config e edite os valores.
    
DOCUMENTAÇÃO:
    INSTALLATION_GUIDE.md - Guia completo passo a passo
    README.md             - Visão geral do projeto
    
EOF
}

main() {
    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                INSTALL_MODE="auto"
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Banner
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║        📊  INSTALAÇÃO AUTOMATIZADA - PLATAFORMA DE DADOS  📊     ║
║                                                                   ║
║              Apache Airflow + Superset + Hop + Docker             ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "========== INÍCIO DA INSTALAÇÃO =========="
    log "Modo: $INSTALL_MODE"
    log "Data: $(date)"
    log "Usuário: $USER"
    log "Diretório: $SCRIPT_DIR"
    
    # Verificações iniciais
    check_root
    check_os
    
    # Carregar configuração
    if [ -n "$CONFIG_FILE" ]; then
        load_config
    elif [ "$AUTO_MODE" = false ]; then
        create_config_interactive
    fi
    
    # Executar instalação
    install_dependencies
    configure_timezone
    
    if [ "$INSTALL_DOCKER" = "yes" ]; then
        install_docker
    fi
    
    if [ "$CONFIGURE_DOCKER_PERMISSIONS" = "yes" ]; then
        configure_docker_permissions
    fi
    
    if [ "$AUTO_GENERATE_SECRETS" = "yes" ]; then
        generate_secrets
    fi
    
    create_env_file
    create_directory_structure
    configure_permissions
    
    if [ "$SETUP_CLOUDFLARE" = "yes" ]; then
        setup_cloudflare_tunnel || true
    fi
    
    if [ "$SETUP_AZURE_SSO" = "yes" ]; then
        setup_azure_sso_config
    fi
    
    deploy_platform
    
    if [ "$RUN_TESTS" = "yes" ]; then
        run_tests
    fi
    
    print_summary
    
    log "========== INSTALAÇÃO CONCLUÍDA =========="
}

# Executar
main "$@"
