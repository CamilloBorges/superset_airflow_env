#!/bin/bash
# =============================================================================
# Script de Validação Pré-Migração
# =============================================================================
# Verifica se o ambiente está pronto para migração OAuth → LDAP
#
# Uso: ./pre-migration-check.sh
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================================"
echo "  Validação Pré-Migração: OAuth → LDAP"
echo "========================================================"
echo ""

# Contadores
ERRORS=0
WARNINGS=0
PASSED=0

# Função para verificar
check() {
    local name="$1"
    local command="$2"
    local type="${3:-error}" # error ou warning
    
    echo -n "Verificando: $name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
        return 0
    else
        if [ "$type" = "warning" ]; then
            echo -e "${YELLOW}⚠${NC}"
            ((WARNINGS++))
        else
            echo -e "${RED}✗${NC}"
            ((ERRORS++))
        fi
        return 1
    fi
}

# =============================================================================
# 1. VERIFICAÇÕES DE AMBIENTE
# =============================================================================

echo "1. Verificações de Ambiente"
echo "----------------------------"

check "Docker instalado" "command -v docker"
check "Docker Compose V2" "docker compose version"
check "Arquivo docker-compose.yml existe" "test -f docker-compose.yml"
check "Arquivo .env existe" "test -f .env"
check "Diretório superset/ existe" "test -d superset"
check "Diretório airflow/ existe" "test -d airflow"

echo ""

# =============================================================================
# 2. VERIFICAÇÕES DE BACKUP
# =============================================================================

echo "2. Verificações de Backup"
echo "-------------------------"

# Verificar se existem backups recentes (últimas 24h)
if find . -maxdepth 1 -name "*.backup" -mtime -1 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓${NC} Backups encontrados nas últimas 24h"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Nenhum backup encontrado (recomendado criar)"
    ((WARNINGS++))
fi

# Verificar espaço em disco
DISK_AVAIL=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "${DISK_AVAIL%.*}" -gt 10 ]; then
    echo -e "${GREEN}✓${NC} Espaço em disco suficiente (${DISK_AVAIL}G disponível)"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Espaço em disco insuficiente (apenas ${DISK_AVAIL}G disponível)"
    ((ERRORS++))
fi

echo ""

# =============================================================================
# 3. VERIFICAÇÕES DE CONTAINERS ATUAIS
# =============================================================================

echo "3. Containers Atuais"
echo "--------------------"

if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Containers em execução (será necessário parar)"
    ((PASSED++))
    
    # Listar containers ativos
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | tail -n +2
else
    echo -e "${YELLOW}⚠${NC} Nenhum container em execução"
    ((WARNINGS++))
fi

echo ""

# =============================================================================
# 4. VERIFICAÇÕES DE NOVOS ARQUIVOS
# =============================================================================

echo "4. Novos Arquivos Criados"
echo "--------------------------"

check "docker-compose.new.yml criado" "test -f docker-compose.new.yml"
check "superset_config_ldap.py criado" "test -f superset/config/superset_config_ldap.py"
check "webserver_config_ldap.py criado" "test -f airflow/config/webserver_config_ldap.py"
check ".env.ldap.example criado" "test -f .env.ldap.example"
check "ldap/bootstrap.ldif criado" "test -f ldap/bootstrap.ldif"
check "README.new.md criado" "test -f README.new.md"
check "MIGRATION_GUIDE.md criado" "test -f MIGRATION_GUIDE.md"

echo ""

# =============================================================================
# 5. VERIFICAÇÕES DE CONFIGURAÇÃO LDAP
# =============================================================================

echo "5. Variáveis LDAP no .env.ldap.example"
echo "---------------------------------------"

if [ -f .env.ldap.example ]; then
    check "LDAP_ORGANISATION definido" "grep -q '^LDAP_ORGANISATION=' .env.ldap.example"
    check "LDAP_DOMAIN definido" "grep -q '^LDAP_DOMAIN=' .env.ldap.example"
    check "LDAP_BASE_DN definido" "grep -q '^LDAP_BASE_DN=' .env.ldap.example"
    check "LDAP_ADMIN_PASSWORD definido" "grep -q '^LDAP_ADMIN_PASSWORD=' .env.ldap.example"
    check "LDAP_HOST definido" "grep -q '^LDAP_HOST=' .env.ldap.example"
else
    echo -e "${RED}✗${NC} .env.ldap.example não encontrado"
    ((ERRORS++))
fi

echo ""

# =============================================================================
# 6. VERIFICAÇÕES DE SINTAXE DOCKER COMPOSE
# =============================================================================

echo "6. Sintaxe Docker Compose"
echo "--------------------------"

if [ -f docker-compose.new.yml ]; then
    if docker compose -f docker-compose.new.yml config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-compose.new.yml sintaxe válida"
        ((PASSED++))
        
        # Verificar serviços importantes
        check "Serviço openldap definido" "docker compose -f docker-compose.new.yml config | grep -q 'openldap:'"
        check "Serviço phpldapadmin definido" "docker compose -f docker-compose.new.yml config | grep -q 'phpldapadmin:'"
        check "Serviço nginx REMOVIDO" "! docker compose -f docker-compose.new.yml config | grep -q 'nginx:'"
        
    else
        echo -e "${RED}✗${NC} docker-compose.new.yml tem erros de sintaxe"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗${NC} docker-compose.new.yml não encontrado"
    ((ERRORS++))
fi

echo ""

# =============================================================================
# 7. VERIFICAÇÕES DE ARQUIVOS OBSOLETOS
# =============================================================================

echo "7. Arquivos Obsoletos (para remover)"
echo "-------------------------------------"

OBSOLETE_FILES=(
    "nginx/nginx.conf"
    "AZURE_KEYVAULT_SETUP.md"
    "KEYVAULT_QUICKSTART.md"
    "configure-managed-identity.sh"
    "deploy-keyvault.sh"
    "fix_csrf.py"
    "superset_session_fix.py"
)

OBSOLETE_COUNT=0
for file in "${OBSOLETE_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo -e "${YELLOW}⚠${NC} Arquivo obsoleto encontrado: $file"
        ((OBSOLETE_COUNT++))
    fi
done

if [ $OBSOLETE_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Nenhum arquivo obsoleto encontrado"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} $OBSOLETE_COUNT arquivo(s) obsoleto(s) encontrado(s)"
    echo "  Execute: rm -f ${OBSOLETE_FILES[@]}"
    ((WARNINGS++))
fi

echo ""

# =============================================================================
# 8. VERIFICAÇÕES DE PORTAS
# =============================================================================

echo "8. Disponibilidade de Portas"
echo "-----------------------------"

PORTS=(389 8082 8088 8080 8081 5432 6379)
PORT_CONFLICTS=0

for port in "${PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        # Porta em uso - verificar se é nosso container
        if docker compose ps 2>/dev/null | grep -q ":$port->"; then
            echo -e "${GREEN}✓${NC} Porta $port em uso pelo Docker Compose (OK)"
        else
            echo -e "${YELLOW}⚠${NC} Porta $port em uso por outro processo"
            ((PORT_CONFLICTS++))
        fi
    else
        echo -e "${GREEN}✓${NC} Porta $port disponível"
    fi
done

if [ $PORT_CONFLICTS -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} $PORT_CONFLICTS porta(s) em conflito"
    ((WARNINGS++))
else
    ((PASSED++))
fi

echo ""

# =============================================================================
# 9. VERIFICAÇÕES DE .ENV ATUAL
# =============================================================================

echo "9. Variáveis Críticas no .env Atual"
echo "------------------------------------"

if [ -f .env ]; then
    CRITICAL_VARS=(
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "SUPERSET_SECRET_KEY"
        "AIRFLOW__CORE__FERNET_KEY"
    )
    
    for var in "${CRITICAL_VARS[@]}"; do
        if grep -q "^${var}=" .env; then
            # Verificar se não é valor padrão
            if ! grep "^${var}=changeme" .env > /dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} $var configurado"
            else
                echo -e "${YELLOW}⚠${NC} $var usa valor padrão (trocar em produção)"
                ((WARNINGS++))
            fi
        else
            echo -e "${RED}✗${NC} $var não encontrado"
            ((ERRORS++))
        fi
    done
    
    # Verificar se tem variáveis Azure (devem ser removidas)
    if grep -q "^AZURE_" .env; then
        echo -e "${YELLOW}⚠${NC} Variáveis AZURE_ encontradas (serão removidas na migração)"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓${NC} Nenhuma variável Azure no .env"
        ((PASSED++))
    fi
else
    echo -e "${RED}✗${NC} .env não encontrado"
    ((ERRORS++))
fi

echo ""

# =============================================================================
# RESUMO FINAL
# =============================================================================

echo "========================================================"
echo "  RESUMO"
echo "========================================================"
echo ""
echo -e "Testes Passados:  ${GREEN}$PASSED${NC}"
echo -e "Avisos:           ${YELLOW}$WARNINGS${NC}"
echo -e "Erros:            ${RED}$ERRORS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ AMBIENTE PRONTO PARA MIGRAÇÃO${NC}"
    echo ""
    echo "Próximos passos:"
    echo "1. Leia MIGRATION_GUIDE.md completamente"
    echo "2. Faça backup completo:"
    echo "   docker exec postgres pg_dumpall -U dataplatform > backup_postgres.sql"
    echo "3. Pare o ambiente atual:"
    echo "   docker compose down"
    echo "4. Siga os passos do MIGRATION_GUIDE.md"
    echo ""
    exit 0
else
    echo -e "${RED}✗ CORRIJA OS ERROS ANTES DE MIGRAR${NC}"
    echo ""
    echo "Erros encontrados: $ERRORS"
    echo "Corrija os problemas acima antes de prosseguir."
    echo ""
    exit 1
fi
