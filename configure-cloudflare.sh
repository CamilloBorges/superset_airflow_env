#!/bin/bash
# configure-cloudflare.sh - Script auxiliar para configurar Cloudflare Tunnel
# Uso: ./configure-cloudflare.sh [token]

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cloudflare Tunnel - Configuração${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se cloudflared está instalado
if ! command -v cloudflared &> /dev/null; then
    echo -e "${YELLOW}cloudflared não encontrado. Instalando...${NC}"
    echo ""
    
    # Baixar cloudflared
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    
    # Instalar
    sudo dpkg -i cloudflared-linux-amd64.deb
    
    # Limpar
    rm cloudflared-linux-amd64.deb
    
    echo -e "${GREEN}✓ cloudflared instalado!${NC}"
    echo ""
fi

# Verificar versão
CLOUDFLARED_VERSION=$(cloudflared --version)
echo -e "${GREEN}cloudflared: $CLOUDFLARED_VERSION${NC}"
echo ""

# Verificar se já existe tunnel configurado
if sudo systemctl is-active --quiet cloudflared; then
    echo -e "${YELLOW}⚠ Cloudflare Tunnel já está rodando!${NC}"
    echo ""
    echo -e "Status atual:"
    sudo systemctl status cloudflared --no-pager
    echo ""
    read -p "Deseja reconfigurar? (s/N): " RECONFIG
    if [[ ! $RECONFIG =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Mantendo configuração existente.${NC}"
        exit 0
    fi
    echo ""
    echo -e "${YELLOW}Parando serviço existente...${NC}"
    sudo systemctl stop cloudflared
    sudo cloudflared service uninstall 2>/dev/null || true
fi

# Token do tunnel
if [ -z "$1" ]; then
    echo -e "${CYAN}Para obter o token do Cloudflare Tunnel:${NC}"
    echo ""
    echo -e "1. Acesse: ${YELLOW}https://dash.cloudflare.com${NC}"
    echo -e "2. Selecione seu domínio: ${YELLOW}bomgado.com.br${NC}"
    echo -e "3. Menu: ${YELLOW}Zero Trust → Access → Tunnels${NC}"
    echo -e "4. Clique ${YELLOW}Create a tunnel${NC} ou selecione existente"
    echo -e "5. Copie o token do comando de instalação"
    echo ""
    read -p "Cole o token aqui: " TUNNEL_TOKEN
else
    TUNNEL_TOKEN=$1
fi

if [ -z "$TUNNEL_TOKEN" ]; then
    echo -e "${RED}✗ Token não fornecido!${NC}"
    exit 1
fi

# Instalar tunnel
echo ""
echo -e "${YELLOW}Instalando Cloudflare Tunnel...${NC}"
sudo cloudflared service install "$TUNNEL_TOKEN"

echo ""
echo -e "${GREEN}✓ Tunnel instalado!${NC}"
echo ""

# Iniciar serviço
echo -e "${YELLOW}Iniciando serviço...${NC}"
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

echo ""
echo -e "${GREEN}✓ Serviço iniciado!${NC}"
echo ""

# Aguardar conexão
echo -e "${YELLOW}Aguardando conexão (10 segundos)...${NC}"
sleep 10

# Verificar status
echo ""
echo -e "${YELLOW}Status do Cloudflare Tunnel:${NC}"
sudo systemctl status cloudflared --no-pager

echo ""
echo -e "${YELLOW}Últimas 20 linhas do log:${NC}"
sudo journalctl -u cloudflared -n 20 --no-pager

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Cloudflare Tunnel configurado!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Próximos passos:${NC}"
echo ""
echo -e "1. Configure Public Hostnames no Cloudflare Dashboard:"
echo -e "   ${YELLOW}https://dash.cloudflare.com${NC}"
echo ""
echo -e "   Hostname 1: ${GREEN}bi.bomgado.com.br${NC} → HTTP → ${GREEN}localhost:80${NC}"
echo -e "   Hostname 2: ${GREEN}airflow.bomgado.com.br${NC} → HTTP → ${GREEN}localhost:8080${NC}"
echo -e "   Hostname 3: ${GREEN}hop.bomgado.com.br${NC} → HTTP → ${GREEN}localhost:8081${NC}"
echo ""
echo -e "2. Atualize o .env:"
echo -e "   ${CYAN}nano .env${NC}"
echo -e "   ${YELLOW}PUBLIC_DOMAIN=bi.bomgado.com.br${NC}"
echo ""
echo -e "3. Inicie a plataforma:"
echo -e "   ${CYAN}docker compose up -d${NC}"
echo ""
echo -e "4. Acesse:"
echo -e "   Superset: ${GREEN}https://bi.bomgado.com.br${NC}"
echo -e "   Airflow:  ${GREEN}https://airflow.bomgado.com.br${NC}"
echo -e "   Hop:      ${GREEN}https://hop.bomgado.com.br${NC}"
echo ""
echo -e "${CYAN}Comandos úteis:${NC}"
echo -e "  Status:  ${YELLOW}sudo systemctl status cloudflared${NC}"
echo -e "  Logs:    ${YELLOW}sudo journalctl -u cloudflared -f${NC}"
echo -e "  Restart: ${YELLOW}sudo systemctl restart cloudflared${NC}"
echo ""
