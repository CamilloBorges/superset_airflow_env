"""
Apache Superset - Configuração Empresarial
===========================================

Ambiente de produção com:
- Azure Entra ID SSO obrigatório
- Redis para sessões persistentes
- PostgreSQL como metadata database
- Celery para tarefas assíncronas
- HTTPS via Cloudflare Tunnel

Autor: Plataforma de Dados Bomgado
Data: 2026-06-06
"""

import os
from celery.schedules import crontab
from flask_appbuilder.security.manager import AUTH_OAUTH
from redis import Redis

# =============================================================================
# SESSÃO PERSISTENTE NO REDIS
# =============================================================================
# CRÍTICO: Configurar ANTES de qualquer outra coisa
# Flask-Session e Authlib precisam disso para OAuth state persistence

SESSION_TYPE = 'redis'
SESSION_REDIS = Redis(
    host=os.getenv('REDIS_HOST', 'redis'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    password=os.getenv('REDIS_PASSWORD'),
    db=0,
    decode_responses=False
)
SESSION_USE_SIGNER = True
SESSION_PERMANENT = False
SESSION_KEY_PREFIX = 'superset:'
SESSION_COOKIE_NAME = 'superset_session'
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_COOKIE_SECURE = False  # Cloudflare Tunnel termina SSL, backend é HTTP

# =============================================================================
# CONFIGURAÇÕES DE REDE E PROXY
# =============================================================================

# Superset está atrás de Cloudflare Tunnel + Nginx
ENABLE_PROXY_FIX = True
PREFERRED_URL_SCHEME = 'https'

# ProxyFix middleware para headers corretos
def FLASK_APP_MUTATOR(app):
    """
    Configura middleware para ambientes de produção atrás de proxy reverso
    """
    from werkzeug.middleware.proxy_fix import ProxyFix
    
    app.wsgi_app = ProxyFix(
        app.wsgi_app,
        x_for=1,      # Número de proxies para X-Forwarded-For
        x_proto=1,    # Número de proxies para X-Forwarded-Proto
        x_host=1,     # Número de proxies para X-Forwarded-Host
        x_port=1,     # Número de proxies para X-Forwarded-Port
        x_prefix=1    # Número de proxies para X-Forwarded-Prefix
    )

# =============================================================================
# SEGURANÇA E AUTENTICAÇÃO
# =============================================================================

# CSRF Protection habilitado (produção)
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = []
WTF_CSRF_TIME_LIMIT = None

# Sem acesso público - SSO obrigatório
# PUBLIC_ROLE_LIKE não definido = força autenticação

# Chave secreta para Flask (do .env)
SECRET_KEY = os.getenv('SUPERSET_SECRET_KEY')

# Timeout de sessão: 12 horas
PERMANENT_SESSION_LIFETIME = 43200

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

# Auto-registrar usuários no primeiro login SSO
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"

# Security Manager customizado para Azure AD
from superset.security import SupersetSecurityManager

class AzureSecurityManager(SupersetSecurityManager):
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
            
            return {
                'username': me.get('userPrincipalName', '').split('@')[0],
                'name': me.get('displayName', ''),
                'email': me.get('mail') or me.get('userPrincipalName'),
                'first_name': me.get('givenName', ''),
                'last_name': me.get('surname', ''),
                'role_keys': ['Gamma'],  # Role padrão para novos usuários
            }
        
        return {}

CUSTOM_SECURITY_MANAGER = AzureSecurityManager

# =============================================================================
# BANCO DE DADOS
# =============================================================================

# PostgreSQL como metadata database
SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://{os.getenv('POSTGRES_USER')}:"
    f"{os.getenv('POSTGRES_PASSWORD')}@"
    f"{os.getenv('POSTGRES_HOST')}:"
    f"{os.getenv('POSTGRES_PORT')}/"
    f"{os.getenv('POSTGRES_DB', 'superset_db')}"
)

# Configurações de pool de conexões
SQLALCHEMY_POOL_SIZE = 10
SQLALCHEMY_MAX_OVERFLOW = 20
SQLALCHEMY_POOL_TIMEOUT = 30
SQLALCHEMY_POOL_RECYCLE = 1800

# =============================================================================
# CELERY - TAREFAS ASSÍNCRONAS
# =============================================================================

class CeleryConfig:
    broker_url = os.getenv('SUPERSET_CELERY_BROKER', f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/1")
    result_backend = os.getenv('SUPERSET_CELERY_RESULT_BACKEND', f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/2")
    
    task_annotations = {
        'sql_lab.get_sql_results': {
            'rate_limit': '100/s',
        },
    }
    
    beat_schedule = {
        'reports.scheduler': {
            'task': 'reports.scheduler',
            'schedule': crontab(minute='*', hour='*'),
        },
        'reports.prune_log': {
            'task': 'reports.prune_log',
            'schedule': crontab(minute=0, hour=0),
        },
    }

CELERY_CONFIG = CeleryConfig

# =============================================================================
# CACHE - REDIS
# =============================================================================

CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_cache_',
    'CACHE_REDIS_URL': f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/3"
}

# Cache para dados de gráficos
DATA_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 86400,  # 24 horas
    'CACHE_KEY_PREFIX': 'superset_data_',
    'CACHE_REDIS_URL': f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/4"
}

# =============================================================================
# FEATURES FLAGS
# =============================================================================

FEATURE_FLAGS = {
    # Habilitar features de produção
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_NATIVE_FILTERS_SET': True,
    'ENABLE_TEMPLATE_PROCESSING': True,
    'ALERT_REPORTS': True,
    'THUMBNAILS': True,
    'LISTVIEWS_DEFAULT_CARD_VIEW': True,
    
    # Desabilitar features de desenvolvimento
    'ENABLE_JAVASCRIPT_CONTROLS': False,
    'ENABLE_TEMPLATE_REMOVE_FILTERS': False,
}

# =============================================================================
# UPLOADS E ARMAZENAMENTO
# =============================================================================

# Tamanho máximo de upload: 50MB
MAX_CONTENT_LENGTH = 50 * 1024 * 1024

# Diretório para uploads
UPLOAD_FOLDER = '/app/superset_home/uploads/'

# Diretório para thumbnails
THUMBNAIL_CACHE_CONFIG = {
    'CACHE_TYPE': 'FileSystemCache',
    'CACHE_DIR': '/app/superset_home/thumbnails/',
    'CACHE_DEFAULT_TIMEOUT': 86400,  # 24 horas
}

# =============================================================================
# TIMEZONE E LOCALIZAÇÃO
# =============================================================================

# Timezone padrão
SUPERSET_TIMEZONE = os.getenv('TIMEZONE', 'America/Sao_Paulo')

# =============================================================================
# SQL LAB
# =============================================================================

# Configurações do SQL Lab
SQLLAB_ASYNC_TIME_LIMIT_SEC = 300
SQLLAB_TIMEOUT = 300
SQLLAB_CTAS_NO_LIMIT = False
SQLLAB_VALIDATION_TIMEOUT = 10

# =============================================================================
# LOGS E DEBUG
# =============================================================================

# Logging em produção
import logging
from logging.handlers import RotatingFileHandler

# Nível de log
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# Configurar logger
LOGGER_HANDLER = RotatingFileHandler(
    '/app/superset_home/superset.log',
    maxBytes=10485760,  # 10MB
    backupCount=10
)
LOGGER_HANDLER.setLevel(logging.INFO)
LOGGER_HANDLER.setFormatter(logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
))

# =============================================================================
# SEGURANÇA ADICIONAL
# =============================================================================

# Content Security Policy
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    'content_security_policy': None,  # Cloudflare já gerencia CSP
    'force_https': False,  # Cloudflare Tunnel termina SSL
}

# Configurações de senha (se usar autenticação local além de SSO)
PASSWORD_MIN_LENGTH = 10
PASSWORD_COMPLEXITY_ENABLED = True

# =============================================================================
# ROW LEVEL SECURITY
# =============================================================================

# Habilitar Row Level Security
ROW_LEVEL_SECURITY = True

# =============================================================================
# WEBDRIVER PARA THUMBNAILS E ALERTS
# =============================================================================

# Configuração do webdriver para screenshots e thumbnails
WEBDRIVER_BASEURL = f"http://superset:{os.getenv('SUPERSET_WEBSERVER_PORT', 8088)}/"
WEBDRIVER_TYPE = 'chrome'
WEBDRIVER_OPTION_ARGS = [
    '--headless',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
]

# =============================================================================
# EMAIL (OPCIONAL - para alerts)
# =============================================================================

# Configurar se quiser enviar alertas por email
# SMTP_HOST = os.getenv('SMTP_HOST', 'localhost')
# SMTP_PORT = int(os.getenv('SMTP_PORT', 25))
# SMTP_STARTTLS = os.getenv('SMTP_STARTTLS', 'True') == 'True'
# SMTP_SSL = os.getenv('SMTP_SSL', 'False') == 'True'
# SMTP_USER = os.getenv('SMTP_USER', '')
# SMTP_PASSWORD = os.getenv('SMTP_PASSWORD', '')
# SMTP_MAIL_FROM = os.getenv('SMTP_MAIL_FROM', 'superset@bomgado.com.br')

# EMAIL_NOTIFICATIONS = True
# EMAIL_HEADER_MUTATOR = None

# =============================================================================
# FIM DA CONFIGURAÇÃO
# =============================================================================
