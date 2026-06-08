#!/bin/bash
# =============================================================================
# Script para Gerar Secrets e Atualizar .env
# =============================================================================

set -e

echo "🔐 Gerando secrets seguros..."

# Funções de geração
generate_password() {
    python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32)))"
}

generate_secret_key() {
    python3 -c "import secrets; print(secrets.token_urlsafe(50))"
}

generate_fernet_key() {
    python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || {
        pip3 install -q cryptography
        python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    }
}

# Gerar senhas
LDAP_ADMIN_PW=$(generate_password)
LDAP_CONFIG_PW=$(generate_password)
LDAP_RO_PW=$(generate_password)
POSTGRES_PW=$(generate_password)
REDIS_PW=$(generate_password)
AIRFLOW_FERNET=$(generate_fernet_key)
AIRFLOW_SECRET=$(generate_secret_key)
SUPERSET_SECRET=$(generate_secret_key)

# Backup do .env atual
if [ -f .env ]; then
    cp .env .env.backup-$(date +%Y%m%d-%H%M%S)
    echo "✓ Backup criado: .env.backup-$(date +%Y%m%d-%H%M%S)"
fi

# Criar novo .env a partir do .env.example
if [ ! -f .env.example ]; then
    echo "❌ .env.example não encontrado!"
    exit 1
fi

cp .env.example .env

# Substituir placeholders no .env
sed -i "s|changeme_ldap_admin_password|${LDAP_ADMIN_PW}|g" .env
sed -i "s|changeme_ldap_config_password|${LDAP_CONFIG_PW}|g" .env
sed -i "s|changeme_readonly_password|${LDAP_RO_PW}|g" .env
sed -i "s|changeme_strong_password|${POSTGRES_PW}|g" .env
sed -i "s|changeme_redis_password|${REDIS_PW}|g" .env
sed -i "s|changeme_generate_with_python_cryptography_fernet|${AIRFLOW_FERNET}|g" .env
sed -i "s|changeme_secret_key_airflow_webserver|${AIRFLOW_SECRET}|g" .env
sed -i "s|changeme_superset_secret_key_min_42_chars_recommended|${SUPERSET_SECRET}|g" .env

# Salvar credenciais em arquivo temporário
CRED_FILE=".credentials-$(date +%Y%m%d-%H%M%S).txt"
cat > "$CRED_FILE" << EOF
# =============================================================================
# Credenciais Geradas - $(date)
# =============================================================================
# ⚠️  GUARDE ESTE ARQUIVO COM SEGURANÇA E DELETE APÓS ANOTAR!
# =============================================================================

# LDAP Admin
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PW}
LDAP_CONFIG_PASSWORD=${LDAP_CONFIG_PW}
LDAP_READONLY_PASSWORD=${LDAP_RO_PW}

# PostgreSQL
POSTGRES_PASSWORD=${POSTGRES_PW}

# Redis
REDIS_PASSWORD=${REDIS_PW}

# Airflow
AIRFLOW__CORE__FERNET_KEY=${AIRFLOW_FERNET}
AIRFLOW__WEBSERVER__SECRET_KEY=${AIRFLOW_SECRET}

# Superset
SUPERSET_SECRET_KEY=${SUPERSET_SECRET}

# =============================================================================
# Senhas de Admin das Aplicações (definidas no código, não no .env)
# =============================================================================
Superset Admin: admin / admin123 (TROQUE após primeiro login!)
Airflow Admin: admin / admin123 (TROQUE após primeiro login!)
LDAP Admin DN: cn=admin,dc=bomgado,dc=local
LDAP Admin Password: admin123 (definido em ldap/bootstrap.ldif)

# =============================================================================
# Acesso às Aplicações
# =============================================================================
Server IP: $(curl -s ifconfig.me 2>/dev/null || echo "IP_PUBLICO_AQUI")

Superset: http://$(curl -s ifconfig.me 2>/dev/null || echo "SERVER_IP"):8088
Airflow: http://$(curl -s ifconfig.me 2>/dev/null || echo "SERVER_IP"):8080
Apache Hop: http://$(curl -s ifconfig.me 2>/dev/null || echo "SERVER_IP"):8081
phpLDAPadmin: http://$(curl -s ifconfig.me 2>/dev/null || echo "SERVER_IP"):8082

# =============================================================================
EOF

echo ""
echo "✅ Secrets gerados com sucesso!"
echo ""
echo "📋 Credenciais salvas em: ${CRED_FILE}"
echo "⚠️  IMPORTANTE: Anote estas credenciais e delete o arquivo!"
echo ""
echo "📁 Visualize as credenciais:"
echo "   cat ${CRED_FILE}"
echo ""
echo "🔄 Para aplicar as mudanças, execute:"
echo "   sudo docker compose down"
echo "   sudo docker compose up -d"
echo ""
