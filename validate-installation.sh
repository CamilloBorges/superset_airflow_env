#!/bin/bash
# validate-installation.sh - Script de Validação Pós-Instalação
# ==============================================================
# Verifica se todos os componentes estão funcionando corretamente
#
# Uso:
#   ./validate-installation.sh
#   ./validate-installation.sh --detailed
#
# ==============================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

DETAILED=false
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Parse argumentos
if [ "$1" = "--detailed" ]; then
    DETAILED=true
fi

print_header() {
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

test_check() {
    local name="$1"
    local result="$2"
    local message="$3"
    
    ((TOTAL_TESTS++))
    
    if [ "$result" = "pass" ]; then
        echo -e "${CHECK} ${name}"
        ((PASSED_TESTS++))
        if [ "$DETAILED" = true ] && [ -n "$message" ]; then
            echo -e "   ${CYAN}→${NC} $message"
        fi
    elif [ "$result" = "fail" ]; then
        echo -e "${CROSS} ${name}"
        ((FAILED_TESTS++))
        if [ -n "$message" ]; then
            echo -e "   ${RED}→${NC} $message"
        fi
    elif [ "$result" = "warn" ]; then
        echo -e "${WARN} ${name}"
        ((WARNING_TESTS++))
        if [ -n "$message" ]; then
            echo -e "   ${YELLOW}→${NC} $message"
        fi
    fi
}

# =============================================================================
# TESTES
# =============================================================================

check_docker() {
    print_header "Docker e Docker Compose"
    
    # Docker instalado
    if command -v docker &> /dev/null; then
        local version=$(docker --version | awk '{print $3}' | sed 's/,//')
        test_check "Docker instalado" "pass" "Versão: $version"
    else
        test_check "Docker instalado" "fail" "Docker não encontrado"
        return 1
    fi
    
    # Docker rodando
    if docker ps &> /dev/null; then
        test_check "Docker daemon rodando" "pass"
    else
        test_check "Docker daemon rodando" "fail" "Verifique: sudo systemctl status docker"
        return 1
    fi
    
    # Docker Compose instalado
    if docker compose version &> /dev/null; then
        local version=$(docker compose version | awk '{print $4}')
        test_check "Docker Compose instalado" "pass" "Versão: $version"
    else
        test_check "Docker Compose instalado" "fail" "Docker Compose não encontrado"
        return 1
    fi
    
    # Permissões do usuário
    if groups | grep -q docker; then
        test_check "Usuário no grupo docker" "pass"
    else
        test_check "Usuário no grupo docker" "warn" "Execute: sudo usermod -aG docker $USER && newgrp docker"
    fi
}

check_env_file() {
    print_header "Arquivo de Configuração (.env)"
    
    # .env existe
    if [ -f ".env" ]; then
        test_check "Arquivo .env existe" "pass"
    else
        test_check "Arquivo .env existe" "fail" "Execute: cp .env.example .env"
        return 1
    fi
    
    # Verificar variáveis críticas
    source .env 2>/dev/null || true
    
    # Secrets configurados
    if [ -n "$POSTGRES_PASSWORD" ] && [ "$POSTGRES_PASSWORD" != "change-me" ]; then
        test_check "POSTGRES_PASSWORD configurado" "pass"
    else
        test_check "POSTGRES_PASSWORD configurado" "fail" "Configure secrets no .env"
    fi
    
    if [ -n "$AIRFLOW__CORE__FERNET_KEY" ]; then
        test_check "AIRFLOW__CORE__FERNET_KEY configurado" "pass"
    else
        test_check "AIRFLOW__CORE__FERNET_KEY configurado" "fail" "Execute: python3 generate_secrets.py"
    fi
    
    if [ -n "$SUPERSET_SECRET_KEY" ]; then
        test_check "SUPERSET_SECRET_KEY configurado" "pass"
    else
        test_check "SUPERSET_SECRET_KEY configurado" "fail" "Configure no .env"
    fi
    
    # Domínio configurado
    if [ -n "$PUBLIC_DOMAIN" ]; then
        test_check "PUBLIC_DOMAIN configurado" "pass" "$PUBLIC_DOMAIN"
    else
        test_check "PUBLIC_DOMAIN configurado" "warn" "Configure para produção"
    fi
}

check_directories() {
    print_header "Estrutura de Diretórios"
    
    local required_dirs=(
        "airflow/logs"
        "airflow/dags"
        "airflow/plugins"
        "airflow/config"
        "superset/config"
        "superset/data"
        "hop/config"
        "hop/projects"
        "hop/metadata"
        "postgres/init-scripts"
        "shared/data"
        "nginx"
    )
    
    local missing=0
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ "$DETAILED" = true ]; then
                test_check "Diretório $dir" "pass"
            fi
        else
            test_check "Diretório $dir" "fail" "Crie com: mkdir -p $dir"
            ((missing++))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        test_check "Todos os diretórios criados" "pass" "${#required_dirs[@]} diretórios OK"
    fi
}

check_containers() {
    print_header "Containers Docker"
    
    # Verificar se docker-compose.yml existe
    if [ ! -f "docker-compose.yml" ]; then
        test_check "docker-compose.yml existe" "fail" "Arquivo não encontrado"
        return 1
    fi
    test_check "docker-compose.yml existe" "pass"
    
    # Containers definidos
    local expected_services=(
        "postgres"
        "redis"
        "airflow-init"
        "airflow-webserver"
        "airflow-scheduler"
        "airflow-worker"
        "airflow-triggerer"
        "superset-init"
        "superset"
        "superset-worker"
        "superset-beat"
        "hop-server"
        "nginx"
    )
    
    # Containers rodando
    local running=0
    local stopped=0
    local missing=0
    
    for service in "${expected_services[@]}"; do
        # Pular containers de init (one-time)
        if [[ "$service" == *"-init" ]]; then
            continue
        fi
        
        local state=$(docker compose ps --format json 2>/dev/null | jq -r "select(.Service == \"$service\") | .State" 2>/dev/null || echo "missing")
        
        if [ "$state" = "running" ]; then
            if [ "$DETAILED" = true ]; then
                test_check "Container $service" "pass" "Running"
            fi
            ((running++))
        elif [ "$state" = "exited" ]; then
            test_check "Container $service" "fail" "Stopped (verifique: docker compose logs $service)"
            ((stopped++))
        else
            test_check "Container $service" "warn" "Não encontrado (talvez ainda não iniciado?)"
            ((missing++))
        fi
    done
    
    if [ $running -gt 0 ]; then
        test_check "Containers rodando" "pass" "$running de $(( running + stopped + missing )) rodando"
    fi
}

check_services() {
    print_header "Serviços HTTP"
    
    # Superset (porta 80 via nginx)
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200\|302"; then
        test_check "Superset (localhost:80)" "pass" "HTTP OK"
    else
        test_check "Superset (localhost:80)" "fail" "Não responde"
    fi
    
    # Airflow (porta 8080)
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
        test_check "Airflow (localhost:8080)" "pass" "HTTP OK"
    else
        test_check "Airflow (localhost:8080)" "fail" "Não responde"
    fi
    
    # Hop (porta 8081)
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|302"; then
        test_check "Hop (localhost:8081)" "pass" "HTTP OK"
    else
        test_check "Hop (localhost:8081)" "fail" "Não responde"
    fi
}

check_cloudflare() {
    print_header "Cloudflare Tunnel"
    
    # cloudflared instalado
    if command -v cloudflared &> /dev/null; then
        local version=$(cloudflared --version 2>&1 | head -n1 | awk '{print $3}')
        test_check "cloudflared instalado" "pass" "Versão: $version"
        
        # Serviço rodando
        if sudo systemctl is-active --quiet cloudflared; then
            test_check "cloudflared service ativo" "pass"
            
            # Verificar logs recentes
            local errors=$(sudo journalctl -u cloudflared -n 20 --no-pager | grep -ci "error\|fail" || echo "0")
            if [ "$errors" -eq 0 ]; then
                test_check "cloudflared sem erros" "pass" "Últimas 20 linhas OK"
            else
                test_check "cloudflared sem erros" "warn" "$errors mensagens de erro nos logs"
            fi
        else
            test_check "cloudflared service ativo" "fail" "Execute: sudo systemctl start cloudflared"
        fi
    else
        test_check "cloudflared instalado" "warn" "Não instalado (opcional se não usar Cloudflare Tunnel)"
    fi
}

check_ssl() {
    print_header "SSL/TLS"
    
    source .env 2>/dev/null || true
    
    if [ -n "$PUBLIC_DOMAIN" ]; then
        # Tentar HTTPS no domínio
        if curl -s -o /dev/null -w "%{http_code}" "https://$PUBLIC_DOMAIN" --max-time 5 | grep -q "200\|302"; then
            test_check "HTTPS funcionando" "pass" "https://$PUBLIC_DOMAIN"
        else
            test_check "HTTPS funcionando" "warn" "Não alcançável (DNS pode não estar propagado)"
        fi
    else
        test_check "Domínio público configurado" "warn" "PUBLIC_DOMAIN não definido"
    fi
}

check_azure_sso() {
    print_header "Azure Entra SSO (Opcional)"
    
    source .env 2>/dev/null || true
    
    if [ -n "$AZURE_TENANT_ID" ]; then
        test_check "AZURE_TENANT_ID configurado" "pass"
        
        if [ -n "$AZURE_SUPERSET_CLIENT_ID" ]; then
            test_check "Superset SSO configurado" "pass"
        else
            test_check "Superset SSO configurado" "warn" "CLIENT_ID não configurado"
        fi
        
        if [ -n "$AZURE_AIRFLOW_CLIENT_ID" ]; then
            test_check "Airflow SSO configurado" "pass"
        else
            test_check "Airflow SSO configurado" "warn" "CLIENT_ID não configurado"
        fi
        
        # Verificar arquivos de config
        if [ -f "airflow/config/webserver_config.py" ]; then
            test_check "Airflow webserver_config.py existe" "pass"
        else
            test_check "Airflow webserver_config.py existe" "warn" "Crie para habilitar SSO"
        fi
        
        if [ -f "superset/config/superset_config.py" ]; then
            test_check "Superset superset_config.py existe" "pass"
        else
            test_check "Superset superset_config.py existe" "warn" "Crie para habilitar SSO"
        fi
    else
        test_check "Azure SSO" "warn" "Não configurado (opcional)"
    fi
}

check_database() {
    print_header "Banco de Dados"
    
    # Verificar se container postgres está rodando
    if docker compose ps | grep -q "postgres.*running"; then
        test_check "PostgreSQL container rodando" "pass"
        
        # Tentar conectar ao banco
        if docker compose exec -T postgres psql -U airflow -d airflow_db -c "SELECT 1" &> /dev/null; then
            test_check "Conexão com airflow_db" "pass"
        else
            test_check "Conexão com airflow_db" "warn" "Banco pode ainda estar inicializando"
        fi
        
        if docker compose exec -T postgres psql -U superset -d superset_db -c "SELECT 1" &> /dev/null; then
            test_check "Conexão com superset_db" "pass"
        else
            test_check "Conexão com superset_db" "warn" "Banco pode ainda estar inicializando"
        fi
    else
        test_check "PostgreSQL container rodando" "fail" "Container não está rodando"
    fi
}

# =============================================================================
# EXECUÇÃO DOS TESTES
# =============================================================================

main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║          ✓  VALIDAÇÃO DA INSTALAÇÃO - PLATAFORMA DE DADOS        ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_docker
    check_env_file
    check_directories
    check_containers
    check_services
    check_database
    check_cloudflare
    check_ssl
    check_azure_sso
    
    # Resumo
    print_header "Resumo da Validação"
    
    echo -e "${GREEN}Testes Passaram:${NC}   $PASSED_TESTS"
    echo -e "${RED}Testes Falharam:${NC}   $FAILED_TESTS"
    echo -e "${YELLOW}Avisos:${NC}            $WARNING_TESTS"
    echo -e "${BLUE}Total de Testes:${NC}   $TOTAL_TESTS"
    echo ""
    
    # Porcentagem
    local percent=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -ne "Taxa de Sucesso: "
    if [ $percent -ge 90 ]; then
        echo -e "${GREEN}$percent%${NC} ${CHECK}"
    elif [ $percent -ge 70 ]; then
        echo -e "${YELLOW}$percent%${NC} ${WARN}"
    else
        echo -e "${RED}$percent%${NC} ${CROSS}"
    fi
    echo ""
    
    # Conclusão
    if [ $FAILED_TESTS -eq 0 ] && [ $WARNING_TESTS -eq 0 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✓✓✓  INSTALAÇÃO PERFEITA - TUDO FUNCIONANDO CORRETAMENTE!  ✓✓✓ ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        exit 0
    elif [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠  INSTALAÇÃO OK COM AVISOS - FUNCIONAL MAS VERIFICAR AVISOS ⚠  ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        exit 0
    else
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗  PROBLEMAS ENCONTRADOS - CORRIJA OS ERROS ACIMA              ✗ ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Documentação de Troubleshooting:${NC}"
        echo "  - TROUBLESHOOTING.md"
        echo "  - SSO_TROUBLESHOOTING.md"
        echo ""
        exit 1
    fi
}

main "$@"
