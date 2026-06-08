"""
Apache Superset - Configuração Empresarial com LDAP
====================================================

Ambiente de produção com:
- Autenticação LDAP unificada
- Redis para sessões e cache
- PostgreSQL como metadata database
- Celery para tarefas assíncronas
- HTTPS via Cloudflare Tunnel

Autor: Plataforma de Dados Bomgado
Data: 2026-06-08
"""

import os
from celery.schedules import crontab
from flask_appbuilder.security.manager import AUTH_LDAP
from redis import Redis

# =============================================================================
# SESSÃO PERSISTENTE NO REDIS
# =============================================================================

SESSION_TYPE = 'redis'
SESSION_REDIS = Redis(
    host=os.getenv('REDIS_HOST', 'redis'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    password=os.getenv('REDIS_PASSWORD'),
    db=1,
    decode_responses=False
)
SESSION_USE_SIGNER = True
SESSION_PERMANENT = False
SESSION_KEY_PREFIX = 'superset:'

# Chave secreta para Flask
SECRET_KEY = os.getenv('SUPERSET_SECRET_KEY')

# Timeout de sessão: 12 horas
PERMANENT_SESSION_LIFETIME = 43200

# Cookie de sessão configurado para HTTPS através de proxy
SESSION_COOKIE_NAME = 'superset_session'
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_COOKIE_SECURE = True

# =============================================================================
# CONFIGURAÇÕES DE REDE E PROXY
# =============================================================================

# Superset está atrás de Cloudflare Tunnel (1 proxy, nginx removido)
ENABLE_PROXY_FIX = True
PREFERRED_URL_SCHEME = 'https'

def FLASK_APP_MUTATOR(app):
    """
    Configura middleware para ambientes de produção atrás de proxy reverso
    """
    from werkzeug.middleware.proxy_fix import ProxyFix
    
    app.wsgi_app = ProxyFix(
        app.wsgi_app,
        x_for=1,      # Apenas Cloudflare (nginx removido)
        x_proto=1,
        x_host=1,
        x_port=1,
        x_prefix=1
    )

# =============================================================================
# SEGURANÇA E AUTENTICAÇÃO LDAP
# =============================================================================

# Tipo de autenticação: LDAP
AUTH_TYPE = AUTH_LDAP

# Configuração do servidor LDAP
AUTH_LDAP_SERVER = f"ldap://{os.getenv('LDAP_HOST', 'openldap')}:{os.getenv('LDAP_PORT', '389')}"

# Base DN para busca de usuários
AUTH_LDAP_SEARCH = os.getenv('LDAP_BASE_DN', 'dc=bomgado,dc=local')

# Campo usado como username (uid, cn, sAMAccountName, etc.)
AUTH_LDAP_UID_FIELD = 'uid'

# Bind DN para autenticação (usuário com permissão de leitura)
AUTH_LDAP_BIND_USER = os.getenv('LDAP_BIND_DN', 'cn=admin,dc=bomgado,dc=local')
AUTH_LDAP_BIND_PASSWORD = os.getenv('LDAP_BIND_PASSWORD', os.getenv('LDAP_ADMIN_PASSWORD'))

# Permitir autenticação direta (bind direto com DN do usuário)
AUTH_LDAP_BIND_FIRST = True

# Mapeamento de atributos LDAP para campos do Superset
AUTH_LDAP_FIRSTNAME_FIELD = 'givenName'
AUTH_LDAP_LASTNAME_FIELD = 'sn'
AUTH_LDAP_EMAIL_FIELD = 'mail'

# Registrar automaticamente novos usuários do LDAP
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = 'Gamma'  # Role padrão para novos usuários

# Mapeamento de grupos LDAP para roles do Superset
AUTH_ROLES_MAPPING = {
    'cn=admins,ou=groups,dc=bomgado,dc=local': ['Admin'],
    'cn=analysts,ou=groups,dc=bomgado,dc=local': ['Alpha', 'Gamma'],
    'cn=viewers,ou=groups,dc=bomgado,dc=local': ['Gamma']
}

# Sincronizar roles a cada login
AUTH_ROLES_SYNC_AT_LOGIN = True

# LDAP TLS (desabilitado pois Cloudflare gerencia TLS)
AUTH_LDAP_USE_TLS = False

# CSRF Protection habilitado (produção)
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = []
WTF_CSRF_TIME_LIMIT = None

# Server-side session storage
SESSION_SERVER_SIDE = True

# =============================================================================
# RECAPTCHA (Desabilitado)
# =============================================================================

# ReCAPTCHA não é necessário em ambiente empresarial interno
RECAPTCHA_PUBLIC_KEY = None
RECAPTCHA_PRIVATE_KEY = None

# =============================================================================
# BANCO DE DADOS
# =============================================================================

SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://{os.getenv('DATABASE_USER', os.getenv('POSTGRES_USER'))}:"
    f"{os.getenv('DATABASE_PASSWORD', os.getenv('POSTGRES_PASSWORD_URLENCODED', os.getenv('POSTGRES_PASSWORD')))}@"
    f"{os.getenv('DATABASE_HOST', os.getenv('POSTGRES_HOST'))}:"
    f"{os.getenv('DATABASE_PORT', os.getenv('POSTGRES_PORT', '5432'))}/"
    f"{os.getenv('DATABASE_DB', os.getenv('POSTGRES_SUPERSET_DB', 'superset_db'))}"
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

# Cache para filtros e state
FILTER_STATE_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 600,
    'CACHE_KEY_PREFIX': 'superset_filter_',
    'CACHE_REDIS_URL': f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/1"
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

# =============================================================================
# LOGGING
# =============================================================================

import logging

LOGGER_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'default': {
            'format': '[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'level': 'INFO',
            'formatter': 'default',
            'stream': 'ext://sys.stdout',
        },
    },
    'root': {
        'level': 'INFO',
        'handlers': ['console'],
    },
}
