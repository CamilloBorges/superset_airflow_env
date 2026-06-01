#!/bin/bash
# generate-ssl-cert.sh - Gera certificado SSL auto-assinado
# Uso: ./generate-ssl-cert.sh [dominio]

set -e

# Carregar variáveis do .env
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Usar domínio do .env ou argumento ou padrão
DOMAIN=${1:-${PUBLIC_DOMAIN:-"localhost"}}

echo "=============================================="
echo "  Gerador de Certificado SSL Auto-assinado"
echo "=============================================="
echo ""
echo "Domínio/IP: $DOMAIN"
echo ""

# Criar diretório para certificados
mkdir -p certs

# Verificar se já existe
if [ -f "certs/cert.pem" ] && [ -f "certs/key.pem" ]; then
    echo "⚠️  Certificados já existem em certs/"
    read -p "Deseja sobrescrever? (s/N): " OVERWRITE
    if [[ ! $OVERWRITE =~ ^[Ss]$ ]]; then
        echo "Operação cancelada."
        exit 0
    fi
    echo ""
fi

echo "📝 Gerando certificado auto-assinado para: $DOMAIN"
echo "   Válido por: 365 dias"
echo ""

# Gerar certificado SSL auto-assinado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/key.pem \
  -out certs/cert.pem \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=DataPlatform/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN,IP:127.0.0.1" \
  2>/dev/null

# Ajustar permissões
chmod 644 certs/cert.pem
chmod 600 certs/key.pem

echo ""
echo "✅ Certificados gerados com sucesso!"
echo ""
echo "📁 Localização:"
echo "   Certificado: $(pwd)/certs/cert.pem"
echo "   Chave:       $(pwd)/certs/key.pem"
echo ""
echo "🔍 Informações do certificado:"
openssl x509 -in certs/cert.pem -noout -subject -dates 2>/dev/null | sed 's/^/   /'
echo ""
echo "📋 Próximos passos:"
echo "   1. Certificados já estão configurados no .env"
echo "   2. Execute: docker compose up -d"
echo "   3. Acesse: https://$DOMAIN"
echo ""
echo "⚠️  AVISO: Certificados auto-assinados causarão aviso no navegador."
echo "   Para produção, use Let's Encrypt (./generate-letsencrypt-cert.sh)"
echo ""
