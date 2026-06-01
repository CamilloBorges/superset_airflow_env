# 🔒 Guia Rápido - Configurar HTTPS para Azure Entra SSO

**Azure Entra ID EXIGE HTTPS para redirect URIs.** Este guia mostra 3 opções para configurar SSL/TLS.

---

## 🎯 Escolha Sua Opção

| Opção | Quando Usar | Dificuldade | Custo |
|-------|-------------|-------------|-------|
| **1. Certificado Auto-assinado** | Desenvolvimento/Teste | ⭐ Fácil | Gratuito |
| **2. Let's Encrypt** | Produção com domínio | ⭐⭐ Médio | Gratuito |
| **3. Nginx Reverse Proxy** | Produção profissional | ⭐⭐⭐ Avançado | Gratuito |

---

## 📝 Opção 1: Certificado Auto-assinado (Mais Rápido)

**Tempo:** 5 minutos  
**Ideal para:** Desenvolvimento e testes internos

### Passo 1: Gerar Certificado

```bash
# No servidor Azure
cd ~/superset_airflow_env

# Criar diretório para certificados
mkdir -p certs

# Gerar certificado auto-assinado (válido 365 dias)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/selfsigned.key \
  -out certs/selfsigned.crt \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=DataPlatform/CN=172.174.210.23"

# Ajustar permissões
chmod 644 certs/selfsigned.crt
chmod 600 certs/selfsigned.key
```

### Passo 2: Atualizar docker-compose.yml

Adicione ao serviço `superset`:

```yaml
superset:
  image: apache/superset:3.0.0
  container_name: superset
  ports:
    - "8088:8088"
    - "8443:8443"  # Porta HTTPS
  environment:
    - SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config_azure.py
    - SUPERSET_WEBSERVER_PROTOCOL=https
    - SUPERSET_WEBSERVER_SSL_CERT_PATH=/app/certs/selfsigned.crt
    - SUPERSET_WEBSERVER_SSL_KEY_PATH=/app/certs/selfsigned.key
  volumes:
    - ./superset/config:/app/pythonpath
    - ./superset/data:/app/superset_home
    - ./certs:/app/certs:ro  # Montar certificados
```

Adicione ao serviço `airflow-webserver`:

```yaml
airflow-webserver:
  <<: *airflow-common
  command: webserver
  ports:
    - "8080:8080"
    - "8443:8443"  # Porta HTTPS
  environment:
    <<: *airflow-common-env
    AIRFLOW__WEBSERVER__CONFIG_FILE: /opt/airflow/config/webserver_config.py
    AIRFLOW__WEBSERVER__WEB_SERVER_SSL_CERT: /opt/airflow/certs/selfsigned.crt
    AIRFLOW__WEBSERVER__WEB_SERVER_SSL_KEY: /opt/airflow/certs/selfsigned.key
  volumes:
    - ./airflow/config:/opt/airflow/config
    - ./certs:/opt/airflow/certs:ro  # Montar certificados
```

### Passo 3: Reiniciar Containers

```bash
docker compose down
docker compose up -d

# Aguardar containers iniciarem
sleep 30

# Testar HTTPS
curl -k https://172.174.210.23:8088/health
curl -k https://172.174.210.23:8080/health
```

### Passo 4: Atualizar NSG (Se Necessário)

Se estiver usando porta 8443 em vez de 8088/8080:

```bash
# Azure CLI
az network nsg rule create \
  --resource-group SEU_RESOURCE_GROUP \
  --nsg-name SEU_NSG \
  --name Allow-HTTPS-8443 \
  --protocol tcp \
  --priority 340 \
  --destination-port-range 8443 \
  --access Allow
```

### Passo 5: Configurar Redirect URIs no Azure

No Azure Portal → App Registrations:

**Superset:**
```
https://172.174.210.23:8088/oauth-authorized/azure
```

**Airflow:**
```
https://172.174.210.23:8080/oauth-authorized/azure
```

### ⚠️ Aviso de Segurança do Navegador

Certificados auto-assinados causarão aviso no navegador:
- Chrome/Edge: "Sua conexão não é particular"
- Firefox: "Aviso: risco potencial de segurança"

**Solução temporária:** Clique em "Avançado" → "Prosseguir para o site"

---

## 🌐 Opção 2: Let's Encrypt (Produção com Domínio)

**Tempo:** 15 minutos  
**Ideal para:** Produção com domínio próprio  
**Requisitos:** Domínio registrado (ex: dados.suaempresa.com)

### Passo 1: Configurar DNS

Aponte seu domínio para o IP público da VM Azure:

```
A Record: dados.suaempresa.com → 172.174.210.23
```

### Passo 2: Instalar Certbot

```bash
sudo apt update
sudo apt install certbot -y
```

### Passo 3: Parar Containers Temporariamente

```bash
cd ~/superset_airflow_env
docker compose down
```

### Passo 4: Obter Certificado

```bash
# Certbot standalone (usa porta 80)
sudo certbot certonly --standalone -d dados.suaempresa.com

# Ou para múltiplos domínios
sudo certbot certonly --standalone \
  -d superset.suaempresa.com \
  -d airflow.suaempresa.com
```

Certificados serão salvos em:
```
/etc/letsencrypt/live/dados.suaempresa.com/fullchain.pem
/etc/letsencrypt/live/dados.suaempresa.com/privkey.pem
```

### Passo 5: Copiar Certificados

```bash
# Criar diretório
mkdir -p ~/superset_airflow_env/certs

# Copiar certificados (com permissões adequadas)
sudo cp /etc/letsencrypt/live/dados.suaempresa.com/fullchain.pem \
  ~/superset_airflow_env/certs/cert.pem

sudo cp /etc/letsencrypt/live/dados.suaempresa.com/privkey.pem \
  ~/superset_airflow_env/certs/key.pem

# Ajustar propriedade
sudo chown $USER:$USER ~/superset_airflow_env/certs/*
chmod 644 ~/superset_airflow_env/certs/cert.pem
chmod 600 ~/superset_airflow_env/certs/key.pem
```

### Passo 6: Atualizar docker-compose.yml

Use `cert.pem` e `key.pem` em vez de `selfsigned.*` (mesmo esquema da Opção 1).

### Passo 7: Renovação Automática

Let's Encrypt expira em 90 dias. Configure renovação automática:

```bash
# Adicionar ao crontab
sudo crontab -e

# Adicione esta linha (renova semanalmente)
0 3 * * 1 certbot renew --quiet && cp /etc/letsencrypt/live/dados.suaempresa.com/*.pem ~/superset_airflow_env/certs/ && cd ~/superset_airflow_env && docker compose restart superset airflow-webserver
```

---

## 🚀 Opção 3: Nginx Reverse Proxy (Recomendado para Produção)

**Tempo:** 30 minutos  
**Ideal para:** Produção profissional  
**Benefícios:** Load balancing, cache, segurança adicional

### Passo 1: Criar Configuração Nginx

Crie `nginx/nginx.conf`:

```nginx
upstream superset_backend {
    server superset:8088;
}

upstream airflow_backend {
    server airflow-webserver:8080;
}

# Redirecionar HTTP para HTTPS
server {
    listen 80;
    server_name 172.174.210.23;
    return 301 https://$server_name$request_uri;
}

# Superset HTTPS
server {
    listen 443 ssl http2;
    server_name 172.174.210.23;

    # Certificados SSL
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Superset
    location /superset/ {
        proxy_pass http://superset_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
    }

    # OAuth callback
    location /oauth-authorized/azure {
        proxy_pass http://superset_backend/oauth-authorized/azure;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# Airflow HTTPS (porta 8443)
server {
    listen 8443 ssl http2;
    server_name 172.174.210.23;

    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://airflow_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

### Passo 2: Adicionar Nginx ao docker-compose.yml

```yaml
nginx:
  image: nginx:alpine
  container_name: nginx-proxy
  ports:
    - "80:80"
    - "443:443"
    - "8443:8443"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./certs:/etc/nginx/certs:ro
  depends_on:
    - superset
    - airflow-webserver
  networks:
    - data-platform-network
  restart: unless-stopped
```

### Passo 3: Atualizar NSG no Azure

```bash
# Permitir porta 443 (HTTPS)
az network nsg rule create \
  --resource-group SEU_RESOURCE_GROUP \
  --nsg-name SEU_NSG \
  --name Allow-HTTPS-443 \
  --protocol tcp \
  --priority 350 \
  --destination-port-range 443 \
  --access Allow

# Porta 8443 para Airflow
az network nsg rule create \
  --resource-group SEU_RESOURCE_GROUP \
  --nsg-name SEU_NSG \
  --name Allow-HTTPS-8443 \
  --protocol tcp \
  --priority 360 \
  --destination-port-range 8443 \
  --access Allow
```

### Passo 4: Iniciar Serviços

```bash
docker compose up -d
```

### Passo 5: Testar

```bash
# Superset
curl -k https://172.174.210.23/superset/

# Airflow
curl -k https://172.174.210.23:8443/
```

### Passo 6: Redirect URIs no Azure

**Superset:**
```
https://172.174.210.23/superset/oauth-authorized/azure
```

**Airflow:**
```
https://172.174.210.23:8443/oauth-authorized/azure
```

---

## ✅ Verificar Configuração HTTPS

```bash
# Testar conexão SSL
openssl s_client -connect 172.174.210.23:443 -servername 172.174.210.23

# Verificar certificado
echo | openssl s_client -connect 172.174.210.23:443 2>/dev/null | openssl x509 -noout -dates

# Testar endpoints
curl -k -I https://172.174.210.23:8088/health
curl -k -I https://172.174.210.23:8080/health
```

---

## 🔍 Troubleshooting

### Erro: "SSL certificate problem: self signed certificate"

**Solução:** Use flag `-k` com curl ou aceite o certificado no navegador.

### Erro: "Connection refused" na porta 443

```bash
# Verificar se Nginx está rodando
docker compose ps nginx

# Ver logs do Nginx
docker compose logs nginx

# Verificar porta aberta
sudo ss -tlnp | grep :443
```

### Erro: "502 Bad Gateway" no Nginx

```bash
# Verificar se Superset/Airflow estão rodando
docker compose ps superset airflow-webserver

# Verificar conectividade
docker compose exec nginx ping superset
```

### Renovação Let's Encrypt falhou

```bash
# Renovar manualmente
sudo certbot renew --force-renewal

# Copiar novos certificados
sudo cp /etc/letsencrypt/live/dados.suaempresa.com/*.pem ~/superset_airflow_env/certs/

# Reiniciar
docker compose restart superset airflow-webserver nginx
```

---

## 📋 Checklist HTTPS

- [ ] Certificados SSL gerados (auto-assinado ou Let's Encrypt)
- [ ] Certificados copiados para `~/superset_airflow_env/certs/`
- [ ] Permissões corretas (644 para .crt/.pem, 600 para .key)
- [ ] `docker-compose.yml` atualizado com volumes de certificados
- [ ] Variáveis de ambiente SSL configuradas
- [ ] NSG Azure com portas HTTPS permitidas (443, 8443)
- [ ] Containers reiniciados
- [ ] Teste `curl -k https://IP:PORTA/health` passou
- [ ] Redirect URIs no Azure atualizadas para `https://`
- [ ] Login SSO testado com sucesso

---

## 🎯 Próximos Passos

Após configurar HTTPS:

1. ✅ Configure SSO seguindo [AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)
2. 🔐 Atualize Redirect URIs no Azure Portal para HTTPS
3. 🧪 Teste login SSO: Clique em "Sign in with Azure"
4. 📊 Verifique usuários criados: `docker compose exec superset superset fab list-users`

---

**HTTPS Configurado!** 🔒  
Agora você pode prosseguir com a configuração de Azure Entra SSO.
