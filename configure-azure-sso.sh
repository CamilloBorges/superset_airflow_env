#!/bin/bash
# configure-azure-sso.sh - Script de Configuração Rápida Azure Entra SSO
# Uso: ./configure-azure-sso.sh

set -e

echo "=============================================="
echo "  Configuração Azure Entra ID SSO"
echo "=============================================="
echo ""

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Erro: Execute este script no diretório raiz do projeto"
    exit 1
fi

echo "📋 Este script irá configurar SSO com Azure Entra ID para:"
echo "   - Apache Superset"
echo "   - Apache Airflow"
echo ""
echo "⚠️  Certifique-se de ter criado 2 App Registrations no Azure Portal:"
echo "   1. Apache Superset SSO"
echo "   2. Apache Airflow SSO"
echo ""
read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..."

# Coletar informações
echo ""
echo "=== Azure Tenant ID (mesmo para ambos) ==="
read -p "Digite seu Azure Tenant ID: " AZURE_TENANT_ID

echo ""
echo "=== Superset App Registration ==="
read -p "Digite o Superset Client ID: " AZURE_SUPERSET_CLIENT_ID
read -sp "Digite o Superset Client Secret: " AZURE_SUPERSET_CLIENT_SECRET
echo ""

echo ""
echo "=== Airflow App Registration ==="
read -p "Digite o Airflow Client ID: " AZURE_AIRFLOW_CLIENT_ID
read -sp "Digite o Airflow Client Secret: " AZURE_AIRFLOW_CLIENT_SECRET
echo ""

echo ""
echo "=== URL Pública (HTTPS) ==="
read -p "Digite o IP ou domínio público (ex: 172.174.210.23 ou seu-dominio.com): " PUBLIC_IP
echo ""
echo "⚠️  IMPORTANTE: Azure Entra ID exige HTTPS!"
echo "   Configure SSL/TLS antes (consulte AZURE_ENTRA_SSO.md Passo 0)"

# Adicionar ao .env
echo ""
echo "📝 Adicionando configurações ao .env..."

if ! grep -q "AZURE_TENANT_ID" .env 2>/dev/null; then
    cat >> .env << EOF

# Azure Entra ID SSO Configuration (adicionado em $(date))
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_SUPERSET_CLIENT_ID=$AZURE_SUPERSET_CLIENT_ID
AZURE_SUPERSET_CLIENT_SECRET=$AZURE_SUPERSET_CLIENT_SECRET
AZURE_AIRFLOW_CLIENT_ID=$AZURE_AIRFLOW_CLIENT_ID
AZURE_AIRFLOW_CLIENT_SECRET=$AZURE_AIRFLOW_CLIENT_SECRET
EOF
    echo "✅ Variáveis adicionadas ao .env"
else
    echo "⚠️  Variáveis Azure já existem no .env - pulando"
fi

# Criar configuração do Superset
echo ""
echo "📝 Criando superset/config/superset_config_azure.py..."
mkdir -p superset/config

cat > superset/config/superset_config_azure.py << 'EOF'
# superset_config_azure.py - Auto-gerado
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
            'client_kwargs': {'scope': 'openid email profile User.Read'},
            'access_token_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token",
            'authorize_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/authorize",
            'server_metadata_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/v2.0/.well-known/openid-configuration",
        }
    }
]

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"

from superset.security import SupersetSecurityManager
import requests

class AzureSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'azure':
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

CUSTOM_SECURITY_MANAGER = AzureSecurityManager
EOF

echo "✅ Superset config criado"

# Criar configuração do Airflow
echo ""
echo "📝 Criando airflow/config/webserver_config.py..."
mkdir -p airflow/config

cat > airflow/config/webserver_config.py << 'EOF'
# webserver_config.py - Auto-gerado
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
            'client_kwargs': {'scope': 'openid email profile User.Read'},
            'access_token_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token",
            'authorize_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/authorize",
            'server_metadata_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/v2.0/.well-known/openid-configuration",
        }
    }
]

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"

from airflow.www.security import AirflowSecurityManager
import requests

class AzureSecurityManager(AirflowSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'azure':
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

SECURITY_MANAGER_CLASS = AzureSecurityManager
EOF

echo "✅ Airflow config criado"

# Criar arquivo de requirements para Airflow
echo ""
echo "📝 Criando airflow/requirements.txt..."
echo "authlib>=1.2.0" > airflow/requirements.txt
echo "✅ Requirements criado"

# Instruções finais
echo ""
echo "=============================================="
echo "  ✅ Configuração Concluída!"
echo "=============================================="
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo ""
echo "1. Reinicie os containers:"
echo "   docker compose restart superset superset-worker superset-beat"
echo "   docker compose restart airflow-webserver airflow-scheduler"
echo ""
echo "2. Aguarde os containers iniciarem (30-60 segundos)"
echo ""
echo "3. Acesse as aplicações e teste o login SSO:"
echo "   Superset: https://$PUBLIC_IP:8088"
echo "   Airflow:  https://$PUBLIC_IP:8080"
echo ""
echo "4. Clique em 'Sign in with Azure' e faça login com Microsoft"
echo ""
echo "🔍 Para verificar logs:"
echo "   docker compose logs -f superset | grep -i oauth"
echo "   docker compose logs -f airflow-webserver | grep -i oauth"
echo ""
echo "📚 Documentação completa: AZURE_ENTRA_SSO.md"
echo ""
echo "⚠️  LEMBRE-SE de verificar os Redirect URIs no Azure Portal:"
echo "   Superset: https://$PUBLIC_IP:8088/oauth-authorized/azure"
echo "   Airflow:  https://$PUBLIC_IP:8080/oauth-authorized/azure"
echo ""
echo "🔒 HTTPS é OBRIGATÓRIO para Azure Entra ID!"
echo ""
