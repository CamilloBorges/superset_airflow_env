# =============================================================================
# Dockerfile Customizado do Apache Superset com Autenticação LDAP
# =============================================================================
# Base: Apache Superset 6.1.0
# Adicionado: python-ldap para autenticação LDAP
# =============================================================================

FROM apache/superset:6.1.0

USER root

# Instalar dependências do sistema para python-ldap
RUN apt-get update && apt-get install -y --no-install-recommends \
    libldap2-dev \
    libsasl2-dev \
    ldap-utils \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependências Python dentro do virtualenv do Superset:
# - python-ldap: Autenticação LDAP
# - psycopg2-binary: Driver PostgreSQL
RUN pip install --no-cache-dir --upgrade --force-reinstall \
    --target=/app/.venv/lib/python3.10/site-packages \
    "python-ldap==3.4.3" \
    "psycopg2-binary==2.9.9"

USER superset
