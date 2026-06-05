# Dockerfile Customizado do Apache Superset com authlib para Azure OAuth
FROM apache/superset:6.1.0

USER root

# Instalar dependências necessárias:
# - authlib: OAuth2/OpenID Connect (Flask-AppBuilder 5.0.2+ requer para OAuth)
# - psycopg2-binary: Driver PostgreSQL (não incluído na imagem 6.x por padrão)
RUN pip install --no-cache-dir authlib psycopg2-binary

USER superset
