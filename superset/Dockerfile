# Dockerfile Customizado do Apache Superset com authlib para Azure OAuth
FROM apache/superset:3.0.0

USER root

# Instalar authlib para OAuth2/OpenID Connect
RUN pip install --no-cache-dir authlib

USER superset
