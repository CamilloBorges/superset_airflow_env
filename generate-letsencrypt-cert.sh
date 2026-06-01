#!/bin/bash
# generate-letsencrypt-cert.sh - Obtém certificado Let's Encrypt
# Uso: ./generate-letsencrypt-cert.sh [dominio]
# Requisitos: Domínio com DNS apontando para este servidor

set -e

# Carregar variáveis do .env
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Usar domínio do argumento ou .env
DOMAIN=${1:-${PUBLIC_DOMAIN}}

if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "localhost" ] || [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Erro: Let's Encrypt requer um domínio válido (não IP ou localhost)"
    echo ""
    echo "Uso: ./generate-letsencrypt-cert.sh seu-dominio.com"
    echo ""
    echo "Ou configure PUBLIC_DOMAIN no .env com um domínio válido."
    echo ""
    echo "💡 Para usar IP, execute: ./generate-ssl-cert.sh (certificado auto-assinado)"
    exit 1
fi

echo "=============================================="
echo "  Gerador de Certificado Let's Encrypt"
echo "=============================================="
echo ""
echo "Domínio: $DOMAIN"
echo ""
echo "⚠️  REQUISITOS:"
echo "   1. DNS do domínio deve apontar para este servidor"
echo "   2. Porta 80 deve estar acessível (para validação)"
echo "   3. Certbot instalado (será instalado se necessário)"
echo ""
read -p "Continuar? (s/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Ss]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi

# Verificar se certbot está instalado
if ! command -v certbot &> /dev/null; then
    echo ""
    echo "📦 Certbot não encontrado. Instalando..."
    sudo apt update
    sudo apt install -y certbot
fi

# Parar Nginx temporariamente para liberar porta 80
echo ""
echo "🛑 Parando Nginx temporariamente..."
docker compose stop nginx 2>/dev/null || true

# Obter certificado
echo ""
echo "🔐 Obtendo certificado Let's Encrypt para: $DOMAIN"
echo "   (Isso pode levar alguns minutos...)"
echo ""

sudo certbot certonly --standalone \
  -d "$DOMAIN" \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email \
  || {
    echo ""
    echo "❌ Erro ao obter certificado."
    echo ""
    echo "Possíveis causas:"
    echo "   - DNS não aponta para este servidor"
    echo "   - Porta 80 bloqueada por firewall"
    echo "   - Domínio inválido"
    echo ""
    echo "Reiniciando Nginx..."
    docker compose start nginx 2>/dev/null || true
    exit 1
  }

# Criar diretório para certificados
mkdir -p certs

# Copiar certificados
echo ""
echo "📁 Copiando certificados..."
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" certs/cert.pem
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" certs/key.pem

# Ajustar permissões
sudo chown $USER:$USER certs/*
chmod 644 certs/cert.pem
chmod 600 certs/key.pem

# Reiniciar Nginx
echo ""
echo "🔄 Reiniciando Nginx com novos certificados..."
docker compose up -d nginx

echo ""
echo "✅ Certificado Let's Encrypt obtido com sucesso!"
echo ""
echo "📁 Localização:"
echo "   Certificado: $(pwd)/certs/cert.pem"
echo "   Chave:       $(pwd)/certs/key.pem"
echo ""
echo "🔍 Informações do certificado:"
openssl x509 -in certs/cert.pem -noout -subject -dates 2>/dev/null | sed 's/^/   /'
echo ""
echo "♻️  RENOVAÇÃO AUTOMÁTICA:"
echo ""
echo "Let's Encrypt expira em 90 dias. Configure renovação automática:"
echo ""
echo "sudo crontab -e"
echo ""
echo "# Adicione esta linha (renova toda segunda às 3h da manhã):"
echo "0 3 * * 1 certbot renew --quiet --deploy-hook 'cp /etc/letsencrypt/live/$DOMAIN/*.pem $(pwd)/certs/ && docker compose -f $(pwd)/docker-compose.yml restart nginx'"
echo ""
echo "📋 Próximos passos:"
echo "   1. Acesse: https://$DOMAIN"
echo "   2. Configure Azure Entra SSO (se necessário)"
echo ""
