"""
Apache Airflow - Configuração Webserver Empresarial
===================================================

Ambiente de produção com:
- Azure Entra ID SSO obrigatório
- Flask-AppBuilder 5.x
- Autenticação OAuth2/OpenID Connect

Autor: Plataforma de Dados Bomgado
Data: 2026-06-06
"""

import os
from flask_appbuilder.security.manager import AUTH_OAUTH
from airflow.www.security import AirflowSecurityManager

# =============================================================================
# AZURE ENTRA ID SSO (OAuth 2.0)
# =============================================================================

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

# Auto-registrar usuários no primeiro login SSO
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"  # Roles disponíveis: Admin, Op, User, Viewer, Public

# =============================================================================
# SECURITY MANAGER CUSTOMIZADO
# =============================================================================

class AzureSecurityManager(AirflowSecurityManager):
    """
    Security Manager customizado para integração com Azure Entra ID
    """
    
    def oauth_user_info(self, provider, response=None):
        """
        Extrai informações do usuário do token OAuth do Azure AD
        
        Args:
            provider (str): Nome do provider OAuth ('azure')
            response (dict): Response do OAuth contendo access_token
            
        Returns:
            dict: Informações do usuário para criação/atualização
        """
        if provider == 'azure':
            import requests
            
            access_token = response.get('access_token')
            
            # Obter dados do usuário via Microsoft Graph API
            me = requests.get(
                'https://graph.microsoft.com/v1.0/me',
                headers={'Authorization': f'Bearer {access_token}'}
            ).json()
            
            # Mapear usuário para role padrão
            # Para mapear grupos do Azure AD para roles, consulte documentação
            return {
                'username': me.get('userPrincipalName', '').split('@')[0],
                'name': me.get('displayName', ''),
                'email': me.get('mail') or me.get('userPrincipalName'),
                'first_name': me.get('givenName', ''),
                'last_name': me.get('surname', ''),
                'role_keys': ['Viewer'],  # Role padrão para novos usuários
            }
        
        return {}

SECURITY_MANAGER_CLASS = AzureSecurityManager

# =============================================================================
# MAPEAMENTO DE GRUPOS AZURE AD PARA ROLES (OPCIONAL)
# =============================================================================

# Descomentar e configurar se quiser mapear grupos do Azure AD para roles do Airflow
# Roles disponíveis: Admin, Op, User, Viewer, Public
# 
# AUTH_ROLES_MAPPING = {
#     "Airflow-Admins": ["Admin"],
#     "Airflow-Operators": ["Op"],
#     "Airflow-Users": ["User"],
#     "Airflow-Viewers": ["Viewer"],
# }
# 
# # Sincronizar roles a cada login
# AUTH_ROLES_SYNC_AT_LOGIN = True

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

# Sem acesso público - SSO obrigatório
# AUTH_ROLE_PUBLIC não definido = força autenticação

# CSRF Protection
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# =============================================================================
# SESSION E COOKIES
# =============================================================================

# Timeout de sessão: 12 horas
PERMANENT_SESSION_LIFETIME = 43200

# Configurações de cookies
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_COOKIE_SECURE = False  # Cloudflare Tunnel termina SSL, backend é HTTP

# =============================================================================
# LOGGING
# =============================================================================

import logging
from logging.handlers import RotatingFileHandler

# Nível de log
LOG_LEVEL = logging.INFO

# =============================================================================
# RATE LIMITING
# =============================================================================

# Rate limiting para APIs
RATELIMIT_ENABLED = True
RATELIMIT_STORAGE_URI = f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/5"

# =============================================================================
# FIM DA CONFIGURAÇÃO
# =============================================================================
