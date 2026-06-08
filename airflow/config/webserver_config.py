"""
Apache Airflow - Configuração Webserver Empresarial com LDAP
============================================================

Ambiente de produção com:
- Autenticação LDAP unificada
- Flask-AppBuilder 5.x
- Sincronização de roles via grupos LDAP

Autor: Plataforma de Dados Bomgado
Data: 2026-06-08
"""

import os
from flask_appbuilder.security.manager import AUTH_LDAP
from airflow.www.security import AirflowSecurityManager

# =============================================================================
# AUTENTICAÇÃO LDAP
# =============================================================================

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

# Mapeamento de atributos LDAP para campos do Airflow
AUTH_LDAP_FIRSTNAME_FIELD = 'givenName'
AUTH_LDAP_LASTNAME_FIELD = 'sn'
AUTH_LDAP_EMAIL_FIELD = 'mail'

# Registrar automaticamente novos usuários do LDAP
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"  # Role padrão para novos usuários

# Mapeamento de grupos LDAP para roles do Airflow
# Roles disponíveis: Admin, Op, User, Viewer, Public
AUTH_ROLES_MAPPING = {
    'cn=admins,ou=groups,dc=bomgado,dc=local': ['Admin'],
    'cn=analysts,ou=groups,dc=bomgado,dc=local': ['Op', 'User'],
    'cn=viewers,ou=groups,dc=bomgado,dc=local': ['Viewer']
}

# Sincronizar roles a cada login
AUTH_ROLES_SYNC_AT_LOGIN = True

# LDAP TLS (desabilitado pois Cloudflare gerencia TLS)
AUTH_LDAP_USE_TLS = False

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

# Sem acesso público - autenticação obrigatória
# AUTH_ROLE_PUBLIC não definido = força autenticação

# CSRF Protection
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# =============================================================================
# SESSION E COOKIES
# =============================================================================

# Timeout de sessão: 12 horas
PERMANENT_SESSION_LIFETIME = 43200

# Configurações de cookies (Cloudflare Tunnel termina SSL)
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_COOKIE_SECURE = True

# =============================================================================
# LOGGING
# =============================================================================

import logging

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
