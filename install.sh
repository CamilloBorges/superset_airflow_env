#!/bin/bash
# =============================================================================
# Script de Instalação Automatizada - Plataforma de Dados
# =============================================================================
# Instala ambiente completo em Ubuntu zerado (24.04 ou 22.04)
#
# Componentes:
# - Docker Engine + Compose
# - PostgreSQL 15, Redis 7, OpenLDAP
# - Apache Superset 6.1.0, Airflow 2.8.0, Hop 2.7.0
# - phpLDAPadmin
#
# Uso: sudo bash install.sh
# =============================================================================

set -e
set -o pipefail

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
clear
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}                                                                ${NC}"
echo -e "${BLUE}   ██████╗  █████╗ ████████╗ █████╗     ██████╗ ██╗      ███${NC}"
echo -e "${BLUE}   ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗    ██╔══██╗██║     ██╔═${NC}"
echo -e "${BLUE}   ██║  ██║███████║   ██║   ███████║    ██████╔╝██║     ████${NC}"
echo -e "${BLUE}   ██║  ██║██╔══██║   ██║   ██╔══██║    ██╔═══╝ ██║     ██╔═${NC}"
echo -e "${BLUE}   ██████╔╝██║  ██║   ██║   ██║  ██║    ██║     ███████╗██║ ${NC}"
echo -e "${BLUE}   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝    ╚═╝     ╚══════╝╚═╝ ${NC}"
echo -e "${BLUE}                                                                ${NC}"
echo -e "${BLUE}        Plataforma de Dados - Instalação Automatizada           ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Execute como root: sudo bash install.sh${NC}"
  exit 1
fi

# Verificar Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}⚠ Sistema não é Ubuntu oficial. Continuando...${NC}"
fi

# Verificar RAM
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$RAM_GB" -lt 7 ]; then
    echo -e "${YELLOW}⚠ RAM detectada: ${RAM_GB}GB (mínimo 8GB recomendado)${NC}"
fi

echo -e "${GREEN}✓ Pré-requisitos verificados${NC}"
echo ""

# =============================================================================
# 1. ATUALIZAR SISTEMA
# =============================================================================
echo -e "${YELLOW}[1/8] Atualizando sistema...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get upgrade -y -qq > /dev/null 2>&1
apt-get install -y -qq curl wget git jq python3 python3-pip net-tools ca-certificates gnupg lsb-release > /dev/null 2>&1
echo -e "${GREEN}✓ Sistema atualizado${NC}"

# =============================================================================
# 2. INSTALAR DOCKER
# =============================================================================
echo -e "${YELLOW}[2/8] Instalando Docker Engine...${NC}"

# Remover versões antigas
apt-get remove -y -qq docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true

# GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
chmod a+r /etc/apt/keyrings/docker.gpg

# Repositório
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

# Verificar
if docker --version > /dev/null 2>&1 && docker compose version > /dev/null 2>&1; then
    DOCKER_VER=$(docker --version | cut -d' ' -f3 | tr -d ',')
    COMPOSE_VER=$(docker compose version | awk '{print $4}')
    echo -e "${GREEN}✓ Docker $DOCKER_VER + Compose $COMPOSE_VER instalados${NC}"
else
    echo -e "${RED}❌ Erro ao instalar Docker${NC}"
    exit 1
fi

# Iniciar Docker
systemctl enable docker > /dev/null 2>&1
systemctl start docker

# =============================================================================
# 3. GERAR SECRETS
# =============================================================================
echo -e "${YELLOW}[3/8] Configurando .env e secrets...${NC}"

if [ ! -f .env ]; then
    cp .env.example .env
    
    # Gerar secrets fortes
    if [ -f generate_secrets.py ]; then
        python3 generate_secrets.py 2>/dev/null || {
            # Fallback manual
            SUPERSET_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(42))" 2>/dev/null || openssl rand -base64 42)
            AIRFLOW_FERNET=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || openssl rand -base64 32)
            AIRFLOW_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || openssl rand -base64 32)
            LDAP_ADMIN_PW=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))" 2>/dev/null || openssl rand -base64 16)
            LDAP_CONFIG_PW=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))" 2>/dev/null || openssl rand -base64 16)
            LDAP_RO_PW=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))" 2>/dev/null || openssl rand -base64 16)
            REDIS_PW=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))" 2>/dev/null || openssl rand -base64 16)
            POSTGRES_PW=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))" 2>/dev/null || openssl rand -base64 16)
            HOP_PW=$(python3 -c "import secrets; print(secrets.token_urlsafe(20))" 2>/dev/null || openssl rand -base64 20)
            
            sed -i "s/changeme_superset_secret_key_min_42_chars_recommended/${SUPERSET_SECRET}/" .env
            sed -i "s/changeme_generate_with_python_cryptography_fernet/${AIRFLOW_FERNET}/" .env
            sed -i "s/changeme_secret_key_airflow_webserver/${AIRFLOW_SECRET}/" .env
            sed -i "s/changeme_ldap_admin_password/${LDAP_ADMIN_PW}/" .env
            sed -i "s/changeme_ldap_config_password/${LDAP_CONFIG_PW}/" .env
            sed -i "s/changeme_readonly_password/${LDAP_RO_PW}/" .env
            sed -i "s/changeme_redis_password/${REDIS_PW}/" .env
            sed -i "s/changeme_strong_password/${POSTGRES_PW}/g" .env
            sed -i "s/changeme_hop_server_password/${HOP_PW}/" .env
        }
    fi
    
    echo -e "${GREEN}✓ .env criado com secrets gerados${NC}"
else
    echo -e "${GREEN}✓ .env existente mantido${NC}"
fi

# =============================================================================
# 4. CRIAR DIRETÓRIOS
# =============================================================================
echo -e "${YELLOW}[4/8] Criando estrutura de diretórios...${NC}"

mkdir -p airflow/{logs,dags,plugins,config}
mkdir -p superset/{config,data}
mkdir -p hop/{config,projects,metadata}
mkdir -p postgres/init-scripts
mkdir -p shared/data
mkdir -p ldap

# Permissões Airflow (UID 50000)
chown -R 50000:0 airflow/ 2>/dev/null || true

echo -e "${GREEN}✓ Diretórios criados${NC}"

# =============================================================================
# 5. BUILD IMAGEM SUPERSET
# =============================================================================
echo -e "${YELLOW}[5/8] Buildando imagem customizada do Superset...${NC}"
echo -e "${BLUE}   (pode levar 3-5 minutos)${NC}"

docker compose build --no-cache superset-init > build.log 2>&1 || {
    echo -e "${RED}❌ Erro no build. Ver: build.log${NC}"
    exit 1
}

echo -e "${GREEN}✓ Imagem superset-custom:latest buildada${NC}"
rm -f build.log

# =============================================================================
# 6. INSTALAR CLOUDFLARE TUNNEL (OPCIONAL)
# =============================================================================
echo -e "${YELLOW}[6/9] Cloudflare Tunnel (HTTPS externo - OPCIONAL)${NC}"
echo -e "${BLUE}   Deseja instalar Cloudflare Tunnel agora? (y/N)${NC}"
read -r -t 15 INSTALL_TUNNEL || INSTALL_TUNNEL="n"

if [[ "$INSTALL_TUNNEL" =~ ^[Yy]$ ]]; then
    echo "   Instalando cloudflared..."
    
    # Download e instalação
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
    dpkg -i /tmp/cloudflared.deb > /dev/null 2>&1
    rm -f /tmp/cloudflared.deb
    
    echo -e "${GREEN}✓ cloudflared instalado${NC}"
    echo ""
    echo -e "${BLUE}   Cole o token do Cloudflare Tunnel:${NC}"
    echo -e "${BLUE}   (Acesse https://one.dash.cloudflare.com → Zero Trust → Networks → Tunnels)${NC}"
    read -r TUNNEL_TOKEN
    
    if [ -n "$TUNNEL_TOKEN" ]; then
        cloudflared service install "$TUNNEL_TOKEN" > /dev/null 2>&1
        systemctl start cloudflared
        systemctl enable cloudflared > /dev/null 2>&1
        echo -e "${GREEN}✓ Cloudflare Tunnel configurado e ativo${NC}"
    else
        echo -e "${YELLOW}⚠ Token vazio. Configure depois com:${NC}"
        echo -e "${YELLOW}  sudo cloudflared service install <TOKEN>${NC}"
    fi
else
    echo -e "${BLUE}⏭  Pulado. Instale depois com: wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared-linux-amd64.deb${NC}"
fi

# =============================================================================
# 7. INICIAR CONTAINERS
# =============================================================================
echo -e "${YELLOW}[7/9] Iniciando containers...${NC}"

# --quiet-pull suprime output de download, mostra só criação de containers
docker compose up -d --quiet-pull 2>&1 | grep -E "(Created|Started|Running|Recreated)" || true

echo -e "${GREEN}✓ Containers iniciados${NC}"

# =============================================================================
# 8. AGUARDAR INICIALIZAÇÃO
# =============================================================================
echo -e "${YELLOW}[8/9] Aguardando inicialização (5-10 min primeira vez)...${NC}"

# Função de health check
check_health() {
    docker inspect --format='{{.State.Health.Status}}' "$1" 2>/dev/null || echo "starting"
}

# OpenLDAP
echo -n "   OpenLDAP... "
for i in {1..60}; do
    [ "$(check_health openldap)" = "healthy" ] && { echo -e "${GREEN}OK${NC}"; break; }
    sleep 2
done

# Aplicar configuração de segurança LDAP (desabilitar bind anônimo)
echo -n "   Configurando segurança LDAP... "
cat > /tmp/ldap-disable-anon.ldif << 'EOF'
dn: cn=config
changetype: modify
add: olcDisallows
olcDisallows: bind_anon

dn: cn=config
changetype: modify
add: olcRequires
olcRequires: authc

dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcRequires
olcRequires: authc
EOF

docker exec openldap ldapmodify -Y EXTERNAL -H ldapi:/// -f /dev/stdin < /tmp/ldap-disable-anon.ldif &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SKIP (já configurado)${NC}"
rm -f /tmp/ldap-disable-anon.ldif

# PostgreSQL
echo -n "   PostgreSQL... "
for i in {1..60}; do
    [ "$(check_health postgres)" = "healthy" ] && { echo -e "${GREEN}OK${NC}"; break; }
    sleep 2
done

# Redis
echo -n "   Redis... "
for i in {1..60}; do
    [ "$(check_health redis)" = "healthy" ] && { echo -e "${GREEN}OK${NC}"; break; }
    sleep 2
done

echo "   Aguardando init containers (2 min)..."
sleep 120

# Superset
echo -n "   Superset... "
for i in {1..120}; do
    [ "$(check_health superset)" = "healthy" ] && { echo -e "${GREEN}OK${NC}"; break; }
    sleep 2
done

# Airflow
echo -n "   Airflow... "
for i in {1..120}; do
    [ "$(check_health airflow-webserver)" = "healthy" ] && { echo -e "${GREEN}OK${NC}"; break; }
    sleep 2
done

# =============================================================================
# 9. VALIDAÇÃO FINAL
# =============================================================================
echo -e "${YELLOW}[9/9] Validando instalação...${NC}"

RUNNING=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.State == "running") | .Name' | wc -l)
echo -e "${GREEN}✓ $RUNNING containers rodando${NC}"

# =============================================================================
# FINALIZAÇÃO
# =============================================================================
echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}                  🎉 INSTALAÇÃO CONCLUÍDA! 🎉                   ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""

# Obter IP do servidor
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${YELLOW}📡 Acesse localmente (antes de configurar Cloudflare):${NC}"
echo ""
echo "  🔹 Superset:     http://${SERVER_IP}:8088"
echo "  🔹 Airflow:      http://${SERVER_IP}:8080"
echo "  🔹 Hop:          http://${SERVER_IP}:8081"
echo "  🔹 phpLDAPadmin: http://${SERVER_IP}:8082"
echo ""

echo -e "${YELLOW}🔑 Login LDAP padrão:${NC}"
echo "  Username: admin"
echo "  Password: admin123"
echo ""

echo -e "${YELLOW}🔐 Acesso phpLDAPadmin:${NC}"
echo "  Login DN: cn=admin,dc=bomgado,dc=local"
echo "  Password: (veja LDAP_ADMIN_PASSWORD no arquivo .credentials-*.txt)"
echo "  ⚠️  NÃO é 'admin123'! Use a senha gerada do .env"
echo "  🔒 Acesso anônimo DESABILITADO"
echo ""

echo -e "${YELLOW}📚 Próximos passos:${NC}"
echo ""

# Verificar se cloudflared está instalado
if command -v cloudflared &> /dev/null && systemctl is-active --quiet cloudflared; then
    echo "  ✅ Cloudflare Tunnel ATIVO"
    echo ""
    echo "  🌐 Configure rotas no Dashboard Cloudflare:"
    echo "     https://one.dash.cloudflare.com → Seu Tunnel → Public Hostnames"
    echo ""
    echo "     • bi.seudominio.com → http://localhost:8088"
    echo "     • airflow.seudominio.com → http://localhost:8080"
    echo "     • hop.seudominio.com → http://localhost:8081"
    echo "     • ldap.seudominio.com → http://localhost:8082"
    echo ""
elif command -v cloudflared &> /dev/null; then
    echo "  ⚠️  Cloudflare Tunnel instalado mas NÃO configurado"
    echo ""
    echo "  🔧 Configure com:"
    echo "     sudo cloudflared service install <SEU_TOKEN>"
    echo "     sudo systemctl start cloudflared"
    echo ""
else
    echo "  1️⃣  Configure Cloudflare Tunnel para HTTPS externo:"
    echo "     • Instale: wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
    echo "     • sudo dpkg -i cloudflared-linux-amd64.deb"
    echo "     • sudo cloudflared service install <TOKEN>"
    echo "     • Configure rotas: bi.seudominio.com.br → http://localhost:8088"
    echo ""
fi

echo "  2️⃣  Acesse phpLDAPadmin e crie usuários:"
echo "     • Navegue até ou=users,dc=bomgado,dc=local"
echo "     • Create new entry → inetOrgPerson"
echo "     • Adicione aos grupos (admins, analysts, viewers)"
echo ""
echo "  3️⃣  TROQUE senhas padrão (IMPORTANTE!):"
echo "     • Edite .env e altere:"
echo "       - LDAP_ADMIN_PASSWORD"
echo "       - POSTGRES_PASSWORD"
echo "       - REDIS_PASSWORD"
echo "     • Depois: docker compose down && docker compose up -d"
echo ""
echo "  4️⃣  Configure backup automático dos volumes"
echo ""

echo -e "${GREEN}📖 Documentação completa: README.md${NC}"
echo -e "${GREEN}🐛 Logs: docker compose logs -f${NC}"
echo -e "${GREEN}📊 Status: docker compose ps${NC}"
echo ""

# Salvar credenciais em arquivo seguro
CREDS_FILE=".credentials-$(date +%Y%m%d-%H%M%S).txt"
cat > "$CREDS_FILE" << EOF
# Credenciais Geradas - $(date)
# GUARDE ESTE ARQUIVO COM SEGURANÇA E DELETE APÓS ANOTAR!

LDAP Admin Password: $(grep LDAP_ADMIN_PASSWORD .env | cut -d'=' -f2)
PostgreSQL Password: $(grep POSTGRES_PASSWORD= .env | head -1 | cut -d'=' -f2)
Redis Password: $(grep REDIS_PASSWORD .env | cut -d'=' -f2)

Superset Admin: admin / admin123 (TROQUE!)
Airflow Admin: admin / admin123 (TROQUE!)
LDAP Admin: admin / admin123 (TROQUE!)

Server IP: ${SERVER_IP}
EOF

chmod 600 "$CREDS_FILE"
echo -e "${YELLOW}💾 Credenciais salvas em: ${CREDS_FILE}${NC}"
echo -e "${RED}   ⚠ DELETE este arquivo após anotar as senhas!${NC}"
echo ""
