"""
Configuração Customizada do Apache Superset
=============================================

Este arquivo permite customizações avançadas do Superset.
Para usar, monte este arquivo no container do Superset.

Documentação: https://superset.apache.org/docs/configuration/configuring-superset
"""

import os
from celery.schedules import crontab
from flask_appbuilder.security.manager import AUTH_OAUTH
import redis

# =============================================================================
# CONFIGURAÇÕES DE SSO - AZURE ENTRA ID
# =============================================================================

# Habilitar proxy fix para HTTPS atrás do Cloudflare Tunnel
ENABLE_PROXY_FIX = True
PREFERRED_URL_SCHEME = 'https'

# IMPORTANTE: Remover PUBLIC_ROLE_LIKE para forçar autenticação
# Se definido como "Gamma", permite acesso sem login (páginas sem proteção)
# PUBLIC_ROLE_LIKE = "Gamma"  # REMOVIDO - forçar autenticação obrigatória

WTF_CSRF_ENABLED = True
# Temporariamente desabilitar CSRF para OAuth endpoints para debugging
WTF_CSRF_EXEMPT_LIST = ['.*login.*', '.*oauth.*']
WTF_CSRF_TIME_LIMIT = None

# =============================================================================
# SESSÃO NO REDIS - CRÍTICO PARA OAUTH FUNCIONAR
# =============================================================================
# Configurar Flask-Session com Redis ANTES do FLASK_APP_MUTATOR
# Isso garante que Authlib/OAuth use sessão persistente

SESSION_TYPE = 'redis'
SESSION_REDIS = redis.from_url(
    f"redis://:{os.getenv('REDIS_PASSWORD')}@{os.getenv('REDIS_HOST')}:{os.getenv('REDIS_PORT')}/0"
)
SESSION_USE_SIGNER = True
SESSION_PERMANENT = False
SESSION_COOKIE_SECURE = False  # FIXME: True em produção com HTTPS
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_COOKIE_NAME = 'superset_session'

# Configurar ProxyFix para HTTPS por trás do Cloudflare/nginx
def FLASK_APP_MUTATOR(app):
    from werkzeug.middleware.proxy_fix import ProxyFix
    from flask_session import Session
    
    # ProxyFix para HTTPS
    app.wsgi_app = ProxyFix(
        app.wsgi_app,
        x_for=1,
        x_proto=1,
        x_host=1,
        x_port=1,
        x_prefix=1
    )
    
    # Inicializar Flask-Session com as configurações acima
    Session(app)
    
    # Configurar cookies de remember-me
    app.config['REMEMBER_COOKIE_SECURE'] = False  # FIXME: True em produção
    app.config['REMEMBER_COOKIE_HTTPONLY'] = True
    app.config['REMEMBER_COOKIE_SAMESITE'] = 'Lax'

# =============================================================================
# AZURE OAUTH - Azure Entra ID
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
                'role_keys': ['Gamma'],  # Atribuir role Gamma por padrão
            }
        return {}

CUSTOM_SECURITY_MANAGER = AzureSecurityManager

# =============================================================================
# CONFIGURAÇÕES DE BANCO DE DADOS
# =============================================================================

# String de conexão com PostgreSQL
SQLALCHEMY_DATABASE_URI = (
    f"postgresql://{os.getenv('DATABASE_USER')}:"
    f"{os.getenv('DATABASE_PASSWORD')}@"
    f"{os.getenv('DATABASE_HOST')}:"
    f"{os.getenv('DATABASE_PORT')}/"
    f"{os.getenv('DATABASE_DB')}"
)

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

# Secret key para sessões e criptografia
SECRET_KEY = os.getenv('SUPERSET_SECRET_KEY')

# Tempo de vida da sessão (em segundos)
PERMANENT_SESSION_LIFETIME = 86400  # 24 horas

# Configurações de senha
PASSWORD_MIN_LENGTH = 8
PASSWORD_COMPLEXITY_ENABLED = True

# =============================================================================
# CONFIGURAÇÕES DO CELERY
# =============================================================================

class CeleryConfig:
    broker_url = f"redis://:{os.getenv('REDIS_PASSWORD')}@{os.getenv('REDIS_HOST')}:6379/1"
    result_backend = f"redis://:{os.getenv('REDIS_PASSWORD')}@{os.getenv('REDIS_HOST')}:6379/2"
    
    # Configurações de worker
    worker_prefetch_multiplier = 4
    worker_max_tasks_per_child = 128
    
    # Tarefas agendadas
    beat_schedule = {
        'cache-warmup-hourly': {
            'task': 'cache-warmup',
            'schedule': crontab(minute=0, hour='*/1'),  # A cada hora
            'kwargs': {},
        },
        'reports-prune-log': {
            'task': 'reports.prune_log',
            'schedule': crontab(minute=0, hour=0),  # Diariamente à meia-noite
        },
    }

CELERY_CONFIG = CeleryConfig

# =============================================================================
# CONFIGURAÇÕES DE CACHE
# =============================================================================

# Cache principal (Redis)
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 86400,  # 24 horas
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': os.getenv('REDIS_HOST'),
    'CACHE_REDIS_PORT': int(os.getenv('REDIS_PORT')),
    'CACHE_REDIS_PASSWORD': os.getenv('REDIS_PASSWORD'),
    'CACHE_REDIS_DB': 3,
}

# Cache de dados
DATA_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 86400,
    'CACHE_KEY_PREFIX': 'superset_data_',
    'CACHE_REDIS_HOST': os.getenv('REDIS_HOST'),
    'CACHE_REDIS_PORT': int(os.getenv('REDIS_PORT')),
    'CACHE_REDIS_PASSWORD': os.getenv('REDIS_PASSWORD'),
    'CACHE_REDIS_DB': 4,
}

# =============================================================================
# CONFIGURAÇÕES DE UPLOAD
# =============================================================================

# Permitir upload de arquivos CSV/Excel
CSV_TO_HIVE_UPLOAD_DIRECTORY_FUNC = lambda: '/app/superset_data/uploads'
ALLOWED_EXTENSIONS = {'csv', 'xlsx', 'xls', 'txt', 'parquet'}

# Tamanho máximo de upload (em bytes) - 100MB
MAX_CONTENT_LENGTH = 100 * 1024 * 1024

# =============================================================================
# CONFIGURAÇÕES DE VISUALIZAÇÃO
# =============================================================================

# Limite de linhas para preview
ROW_LIMIT = 50000

# Limite de linhas para SQL Lab
SQL_MAX_ROW = 100000

# Timeout para queries (em segundos)
SUPERSET_WEBSERVER_TIMEOUT = 300  # 5 minutos

# =============================================================================
# FEATURE FLAGS
# =============================================================================

FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_NATIVE_FILTERS_SET': True,
    'EMBEDDED_SUPERSET': True,
    'ALERT_REPORTS': True,
    'THUMBNAILS': True,
    'DASHBOARD_RBAC': True,
}

# =============================================================================
# CONFIGURAÇÕES DE EMAIL (para alertas e relatórios)
# =============================================================================

# Descomente e configure para habilitar envio de emails
# SMTP_HOST = 'smtp.gmail.com'
# SMTP_STARTTLS = True
# SMTP_SSL = False
# SMTP_USER = 'seu-email@gmail.com'
# SMTP_PORT = 587
# SMTP_PASSWORD = 'sua-senha'
# SMTP_MAIL_FROM = 'seu-email@gmail.com'

# =============================================================================
# CONFIGURAÇÕES DE LOGGING
# =============================================================================

# Nível de log
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# Formato de log
LOG_FORMAT = '%(asctime)s:%(levelname)s:%(name)s:%(message)s'

# =============================================================================
# CONFIGURAÇÕES DE PERFORMANCE
# =============================================================================

# Pool de conexões do SQLAlchemy
SQLALCHEMY_POOL_SIZE = 10
SQLALCHEMY_POOL_TIMEOUT = 30
SQLALCHEMY_MAX_OVERFLOW = 20

# =============================================================================
# MAPBOX (para visualizações geográficas)
# =============================================================================

# Configure se for usar visualizações de mapas
# MAPBOX_API_KEY = 'seu-mapbox-token-aqui'

# =============================================================================
# CUSTOMIZAÇÕES DE UI
# =============================================================================

# Nome da aplicação
APP_NAME = "Data Platform BI"

# Ícone customizado (coloque sua logo em /app/superset/static/assets/images/)
# APP_ICON = "/static/assets/images/custom_logo.png"

# Tema padrão
# THEME_OVERRIDES = {
#     'colors': {
#         'primary': '#1890ff',
#     }
# }

# =============================================================================
# WEBHOOKS (para integração com Airflow, Slack, etc.)
# =============================================================================

ALERT_REPORTS_NOTIFICATION_DRY_RUN = False

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA AVANÇADAS
# =============================================================================

# CORS (se precisar acessar de outros domínios)
ENABLE_CORS = False
# CORS_OPTIONS = {
#     'supports_credentials': True,
#     'allow_headers': ['*'],
#     'resources': ['*'],
#     'origins': ['http://localhost:3000']
# }

# Proteção contra clickjacking
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    'content_security_policy': None,
    'force_https': False,
}

# =============================================================================
# JINJA TEMPLATES
# =============================================================================

# Permitir templates Jinja nas queries SQL
ENABLE_TEMPLATE_PROCESSING = True

# Contexto customizado para templates
JINJA_CONTEXT_ADDONS = {
    'custom_var': 'custom_value',
}

# =============================================================================
# FIM DA CONFIGURAÇÃO
# =============================================================================

print("✓ Configurações customizadas do Superset carregadas com sucesso!")
