# Dockerfile Customizado do Apache Superset com authlib para Azure OAuth
FROM apache/superset:6.1.0

USER root

# Instalar authlib para OAuth2/OpenID Connect
# Flask-AppBuilder 5.0.2+ requer authlib para OAuth providers (extra 'oauth')
RUN pip install --no-cache-dir authlib

USER superset
