#!/bin/bash

# =============================================================================
# Quick Start Script - Data Platform
# =============================================================================
# Script de inicialização rápida para Linux/Mac (Bash)
#
# Uso:
#   chmod +x quick-start.sh
#   ./quick-start.sh
# =============================================================================

# Cores
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Data Platform - Quick Start${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se Docker está rodando
echo -e "${YELLOW}Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker não está instalado!${NC}"
    echo -e "${YELLOW}  Por favor, instale o Docker: https://docs.docker.com/get-docker/${NC}"
    echo ""
    echo -e "${CYAN}Para Ubuntu Server, consulte: UBUNTU_SETUP.md${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker não está rodando!${NC}"
    echo -e "${YELLOW}  Por favor, inicie o Docker.${NC}"
    exit 1
fi

DOCKER_VERSION=$(docker --version)
echo -e "${GREEN}✓ Docker encontrado: $DOCKER_VERSION${NC}"

# Verificar se Docker Compose está disponível
echo -e "${YELLOW}Verificando Docker Compose...${NC}"
if ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose não está disponível!${NC}"
    exit 1
fi

COMPOSE_VERSION=$(docker compose version)
echo -e "${GREEN}✓ Docker Compose encontrado: $COMPOSE_VERSION${NC}"
echo ""

# Verificar se arquivo .env existe
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Arquivo .env não encontrado. Criando a partir do template...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ Arquivo .env criado!${NC}"
    echo ""
    echo -e "${RED}ATENÇÃO: Você precisa gerar as chaves de segurança!${NC}"
    echo ""
    echo -e "${YELLOW}Execute um dos comandos abaixo para gerar as chaves:${NC}"
    echo -e "${CYAN}  1. Se tiver Python instalado:${NC}"
    echo -e "${NC}     python3 generate_secrets.py${NC}"
    echo ""
    echo -e "${CYAN}  2. Usando Docker:${NC}"
    echo -e '${NC}     docker run --rm python:3.11-slim sh -c "pip install cryptography && python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\"${NC}"'
    echo ""
    echo -e "${YELLOW}Depois de gerar as chaves, edite o arquivo .env com os valores gerados.${NC}"
    echo ""
    
    read -p "Deseja continuar mesmo assim? (s/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Abortando...${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}✓ Arquivo .env encontrado!${NC}"
fi

echo ""

# =============================================================================
# Gerar Certificados SSL (HTTPS)
# =============================================================================
echo -e "${YELLOW}Verificando certificados SSL...${NC}"
if [ ! -f "certs/cert.pem" ] || [ ! -f "certs/key.pem" ]; then
    echo -e "${YELLOW}⚠ Certificados SSL não encontrados!${NC}"
    echo ""
    echo -e "${CYAN}Nginx requer HTTPS (Azure Entra SSO exige).${NC}"
    echo ""
    echo -e "Escolha uma opção:"
    echo -e "  ${GREEN}1${NC} - Gerar certificado auto-assinado (desenvolvimento/teste)"
    echo -e "  ${GREEN}2${NC} - Usar Let's Encrypt (produção, requer domínio válido)"
    echo -e "  ${GREEN}3${NC} - Pular (configurar manualmente depois)"
    echo ""
    read -p "Opção (1/2/3): " SSL_OPTION
    
    case $SSL_OPTION in
        1)
            echo ""
            echo -e "${YELLOW}Gerando certificado auto-assinado...${NC}"
            chmod +x generate-ssl-cert.sh 2>/dev/null || true
            ./generate-ssl-cert.sh
            ;;
        2)
            echo ""
            echo -e "${YELLOW}Obtendo certificado Let's Encrypt...${NC}"
            chmod +x generate-letsencrypt-cert.sh 2>/dev/null || true
            ./generate-letsencrypt-cert.sh
            ;;
        3)
            echo ""
            echo -e "${YELLOW}⚠ Pulando geração de certificados.${NC}"
            echo -e "${RED}ATENÇÃO: Nginx NÃO INICIARÁ sem certificados SSL!${NC}"
            echo ""
            echo -e "Execute depois:"
            echo -e "  ${CYAN}./generate-ssl-cert.sh${NC}          (auto-assinado)"
            echo -e "  ${CYAN}./generate-letsencrypt-cert.sh${NC}  (Let's Encrypt)"
            echo ""
            ;;
        *)
            echo -e "${YELLOW}Opção inválida. Gerando certificado auto-assinado...${NC}"
            chmod +x generate-ssl-cert.sh 2>/dev/null || true
            ./generate-ssl-cert.sh
            ;;
    esac
else
    echo -e "${GREEN}✓ Certificados SSL encontrados!${NC}"
fi

echo ""

# Verificar se as chaves foram alteradas do padrão
echo -e "${YELLOW}Verificando configurações de segurança...${NC}"
if grep -q "changeme" .env; then
    echo -e "${RED}⚠ AVISO: Algumas senhas ainda estão com valores padrão!${NC}"
    echo -e "${YELLOW}  Recomenda-se alterar antes de prosseguir em produção.${NC}"
    echo ""
fi

# Obter UID do usuário atual (importante no Linux)
AIRFLOW_UID=$(id -u)
echo -e "${YELLOW}Configurando AIRFLOW_UID=$AIRFLOW_UID${NC}"
if ! grep -q "AIRFLOW_UID=" .env; then
    echo "AIRFLOW_UID=$AIRFLOW_UID" >> .env
else
    sed -i "s/AIRFLOW_UID=.*/AIRFLOW_UID=$AIRFLOW_UID/" .env
fi

# Criar diretórios necessários
echo -e "${YELLOW}Criando estrutura de diretórios...${NC}"
mkdir -p airflow/{logs,dags,plugins,config}
mkdir -p superset/{config,data}
mkdir -p hop/{config,projects,metadata}
mkdir -p postgres/init-scripts
mkdir -p shared/data

# Ajustar permissões (importante no Linux)
echo -e "${YELLOW}Ajustando permissões...${NC}"
chmod -R 755 airflow superset hop postgres shared 2>/dev/null || true
chmod -R 777 airflow/logs 2>/dev/null || true

# Dar permissão de execução aos scripts
chmod +x quick-start.sh 2>/dev/null || true
chmod +x postgres/init-scripts/*.sh 2>/dev/null || true

# Ajustar propriedade para UID do Airflow (50000)
if [ "$(id -u)" != "50000" ]; then
    echo -e "${YELLOW}Ajustando propriedade dos diretórios do Airflow para UID 50000...${NC}"
    if command -v sudo &> /dev/null; then
        sudo chown -R 50000:0 airflow/ 2>/dev/null || {
            echo -e "${YELLOW}⚠ Não foi possível alterar proprietário (sudo necessário)${NC}"
            echo -e "${YELLOW}  Se houver problemas de permissão, execute:${NC}"
            echo -e "${CYAN}  sudo chown -R 50000:0 airflow/${NC}"
        }
    fi
fi

echo -e "${GREEN}✓ Estrutura de diretórios criada!${NC}"
echo ""

# Baixar imagens Docker
echo -e "${YELLOW}Baixando imagens Docker (isso pode levar alguns minutos)...${NC}"
docker compose pull

echo ""
echo -e "${GREEN}✓ Imagens baixadas!${NC}"
echo ""

# Iniciar serviços
echo -e "${YELLOW}Iniciando serviços...${NC}"
echo -e "${CYAN}Isso pode levar de 2 a 5 minutos na primeira vez.${NC}"
echo ""
docker compose up -d

echo ""
echo -e "${GREEN}✓ Serviços iniciados!${NC}"
echo ""

# Aguardar serviços ficarem prontos
echo -e "${YELLOW}Aguardando serviços iniciarem (pode levar até 2 minutos)...${NC}"
sleep 30

# Verificar status
echo ""
echo -e "${YELLOW}Status dos serviços:${NC}"
docker compose ps

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Inicialização Concluída!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Acesse as interfaces web:${NC}"
echo ""
echo -e "${NC}  Apache Airflow:  http://localhost:8080${NC}"
echo -e "${GRAY}    Usuário: admin${NC}"
echo -e "${GRAY}    Senha:   admin123${NC}"
echo ""
echo -e "${NC}  Apache Superset: http://localhost:8088${NC}"
echo -e "${GRAY}    Usuário: admin${NC}"
echo -e "${GRAY}    Senha:   admin123${NC}"
echo ""
echo -e "${NC}  Apache Hop:      http://localhost:8081${NC}"
echo -e "${GRAY}    Usuário: cluster${NC}"
echo -e "${GRAY}    Senha:   cluster${NC}"
echo ""
echo -e "${RED}⚠ IMPORTANTE: Altere as senhas padrão após o primeiro login!${NC}"
echo ""
echo -e "${CYAN}Comandos úteis:${NC}"
echo -e "${NC}  Ver logs:         docker compose logs -f${NC}"
echo -e "${NC}  Parar serviços:   docker compose stop${NC}"
echo -e "${NC}  Iniciar serviços: docker compose start${NC}"
echo -e "${NC}  Status:           docker compose ps${NC}"
echo ""
echo -e "${YELLOW}Documentação completa: README.md${NC}"
echo ""
