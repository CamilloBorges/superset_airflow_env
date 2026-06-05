# Dockerfile Customizado do Apache Superset com authlib para Azure OAuth
FROM apache/superset:6.1.0

USER root

# Instalar dependências necessárias dentro do virtualenv do Superset:
# - authlib: OAuth2/OpenID Connect (Flask-AppBuilder 5.0.2+ requer para OAuth)
# - psycopg2-binary: Driver PostgreSQL (não incluído na imagem 6.x por padrão)
# NOTA: Superset 6.x usa virtualenv em /app/.venv/ - usar python -m pip
RUN /app/.venv/bin/python -m pip install --no-cache-dir authlib psycopg2-binary

USER superset
