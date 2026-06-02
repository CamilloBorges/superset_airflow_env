#!/bin/bash
# fix-sso-config.sh - Script para corrigir configuração SSO
# Execute no servidor: ./fix-sso-config.sh

set -e

echo "=========================================="
echo "🔧 Correção de Configuração SSO"
echo "=========================================="
echo ""

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ ERRO: Execute este script no diretório superset_airflow_env"
    exit 1
fi

# Passo 1: Criar arquivo de configuração Airflow
echo "📝 1/5: Criando airflow/config/webserver_config.py..."
mkdir -p airflow/config
cat > airflow/config/webserver_config.py << 'EOF'
# webserver_config.py - Azure Entra ID OAuth Configuration for Airflow

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
EOF

echo "✅ Arquivo criado: airflow/config/webserver_config.py"

# Passo 2: Criar arquivo de configuração Superset
echo "📝 2/5: Criando superset/config/superset_config.py..."
mkdir -p superset/config
cat > superset/config/superset_config.py << 'EOF'
# superset_config.py - Azure Entra ID OAuth Configuration

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
EOF

echo "✅ Arquivo criado: superset/config/superset_config.py"

# Passo 3: Verificar .env
echo "🔍 3/5: Verificando .env..."
if ! grep -q "AZURE_TENANT_ID=" .env 2>/dev/null; then
    echo "⚠️  AVISO: Variáveis Azure não encontradas no .env"
    echo ""
    echo "Adicione ao .env:"
    echo ""
    echo "AZURE_TENANT_ID=seu_tenant_id"
    echo "AZURE_AIRFLOW_CLIENT_ID=seu_airflow_client_id"
    echo "AZURE_AIRFLOW_CLIENT_SECRET=seu_airflow_secret"
    echo "AZURE_SUPERSET_CLIENT_ID=seu_superset_client_id"
    echo "AZURE_SUPERSET_CLIENT_SECRET=seu_superset_secret"
    echo ""
    read -p "Deseja editar o .env agora? (s/n): " edit_env
    if [ "$edit_env" = "s" ]; then
        nano .env
    fi
else
    echo "✅ Variáveis Azure encontradas no .env"
fi

# Passo 4: Reiniciar containers
echo "🔄 4/5: Reiniciando containers..."
docker compose down
sleep 2
docker compose up -d

echo "⏳ Aguardando containers iniciarem (30s)..."
sleep 30

# Passo 5: Verificar
echo "🔍 5/5: Verificando configuração..."

echo ""
echo "Verificando arquivo Airflow:"
if docker compose exec airflow-webserver test -f /opt/airflow/config/webserver_config.py; then
    echo "✅ webserver_config.py presente no container"
else
    echo "❌ webserver_config.py NÃO encontrado no container"
fi

echo ""
echo "Verificando arquivo Superset:"
if docker compose exec superset test -f /app/superset_home/superset_config.py; then
    echo "✅ superset_config.py presente no container"
else
    echo "❌ superset_config.py NÃO encontrado no container"
fi

echo ""
echo "Verificando variáveis de ambiente Airflow:"
docker compose exec airflow-webserver env | grep -E "^AZURE_" || echo "⚠️  Variáveis Azure não configuradas"

echo ""
echo "Verificando variáveis de ambiente Superset:"
docker compose exec superset env | grep -E "^AZURE_" || echo "⚠️  Variáveis Azure não configuradas"

echo ""
echo "=========================================="
echo "✅ Configuração concluída!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "1. Acesse: https://bi.bomgado.com.br"
echo "2. Clique em 'Sign in with azure'"
echo "3. Faça login com conta Microsoft"
echo "4. Verifique se usuário foi criado:"
echo "   docker compose exec superset superset fab list-users"
echo ""
echo "Para Airflow:"
echo "1. Acesse: https://airflow.bomgado.com.br"
echo "2. Clique em 'Sign in with azure'"
echo "3. Verifique: docker compose exec airflow-webserver airflow users list"
echo ""
