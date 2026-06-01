# 🔒 Guia de Configuração HTTPS

**Azure Entra ID EXIGE HTTPS para redirect URIs.** Este guia mostra como configurar SSL/TLS.

> 💡 **Nginx já está configurado por padrão** neste projeto como reverse proxy HTTPS.

---

## 🎯 Configuração Rápida (2 minutos)

A plataforma já vem com **Nginx reverse proxy** configurado. Você só precisa gerar os certificados SSL:

### Opção A: Certificado Auto-assinado (Desenvolvimento)

```bash
# Gerar certificado auto-assinado
./generate-ssl-cert.sh

# Iniciar plataforma
docker compose up -d
```

### Opção B: Let's Encrypt (Produção com Domínio)

```bash
# Configurar domínio no .env
nano .env
# PUBLIC_DOMAIN=dados.suaempresa.com

# Gerar certificado Let's Encrypt
./generate-letsencrypt-cert.sh

# Iniciar plataforma
docker compose up -d
```

**Pronto!** Acesse:
- **Superset:** https://SEU_DOMINIO (porta 443)
- **Airflow:** https://SEU_DOMINIO:8443
- **Hop:** https://SEU_DOMINIO:8444

---

## 📋 Como Funciona

### Arquitetura HTTPS

```
Cliente HTTPS
    ↓
Nginx (443, 8443, 8444)
    ↓
┌──────────┬──────────┬──────────┐
│ Superset │ Airflow  │   Hop    │
│  :8088   │  :8080   │  :8081   │
└──────────┴──────────┴──────────┘
```

### Nginx já configurado

O `docker-compose.yml` já inclui:

```yaml
nginx:
  image: nginx:alpine
  container_name: nginx-proxy
  ports:
    - "80:80"       # HTTP → Redireciona para HTTPS
    - "443:443"     # HTTPS Superset
    - "8443:8443"   # HTTPS Airflow  
    - "8444:8444"   # HTTPS Hop
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ${SSL_CERT_PATH}:/etc/nginx/certs/cert.pem:ro
    - ${SSL_KEY_PATH}:/etc/nginx/certs/key.pem:ro
```

### Variáveis no .env

```bash
# Domínio ou IP público
PUBLIC_DOMAIN=172.174.210.23

# Caminhos dos certificados
SSL_CERT_PATH=./certs/cert.pem
SSL_KEY_PATH=./certs/key.pem
```

---

## 🔐 Detalhes: Certificado Auto-assinado

**Tempo:** 2 minutos  
**Ideal para:** Desenvolvimento e testes

### Script Automático

```bash
./generate-ssl-cert.sh
```

O script faz:
1. Cria diretório `certs/`
2. Gera certificado válido por 365 dias
3. Configura permissões adequadas
4. Já funciona com Nginx

### Processo Manual

Se preferir gerar manualmente:

```bash
# Criar diretório
mkdir -p certs

# Gerar certificado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/key.pem \
  -out certs/cert.pem \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=DataPlatform/CN=${PUBLIC_DOMAIN}"

# Ajustar permissões
chmod 644 certs/cert.pem
chmod 600 certs/key.pem
```

### ⚠️ Aviso de Segurança

Navegadores mostrarão aviso "Conexão não é segura":
- **Chrome/Edge:** Clique "Avançado" → "Prosseguir"
- **Firefox:** Clique "Avançado" → "Aceitar o risco"

**Isso é normal para certificados auto-assinados.**

---

## 🌐 Detalhes: Let's Encrypt

**Tempo:** 5-10 minutos  
**Ideal para:** Produção com domínio
**Requisitos:** 
- Domínio registrado (ex: `dados.suaempresa.com`)
- DNS apontando para o servidor
- Porta 80 acessível

### Script Automático

```bash
# Configurar domínio no .env primeiro
nano .env
# PUBLIC_DOMAIN=dados.suaempresa.com

# Executar script
./generate-letsencrypt-cert.sh
```

O script faz:
1. Valida domínio
2. Para Nginx temporariamente
3. Obtém certificado via Certbot
4. Copia certificados para `certs/`
5. Reinicia Nginx

### Processo Manual

### Processo Manual

Se preferir fazer manualmente:

```bash
# 1. Instalar certbot
sudo apt update && sudo apt install -y certbot

# 2. Parar Nginx
docker compose stop nginx

# 3. Obter certificado
sudo certbot certonly --standalone -d dados.suaempresa.com

# 4. Copiar certificados
sudo cp /etc/letsencrypt/live/dados.suaempresa.com/fullchain.pem certs/cert.pem
sudo cp /etc/letsencrypt/live/dados.suaempresa.com/privkey.pem certs/key.pem

# 5. Ajustar permissões
sudo chown $USER:$USER certs/*
chmod 644 certs/cert.pem
chmod 600 certs/key.pem

# 6. Reiniciar Nginx
docker compose up -d nginx
```

### Renovação Automática

Let's Encrypt expira em 90 dias. Configure renovação:

```bash
sudo crontab -e

# Adicione esta linha (renova toda segunda às 3h)
0 3 * * 1 certbot renew --quiet --deploy-hook 'cp /etc/letsencrypt/live/dados.suaempresa.com/*.pem /home/azureuser/superset_airflow_env/certs/ && docker compose -f /home/azureuser/superset_airflow_env/docker-compose.yml restart nginx'
```

---

## 🔧 Configuração do Azure Entra SSO

Após configurar HTTPS, configure os redirect URIs no Azure:

### Superset

```
https://SEU_DOMINIO/oauth-authorized/azure
```

Exemplo:
- Com domínio: `https://dados.suaempresa.com/oauth-authorized/azure`
- Com IP: `https://172.174.210.23/oauth-authorized/azure`

### Airflow

```
https://SEU_DOMINIO:8443/oauth-authorized/azure
```

Exemplo:
- Com domínio: `https://dados.suaempresa.com:8443/oauth-authorized/azure`
- Com IP: `https://172.174.210.23:8443/oauth-authorized/azure`

> 💡 Use a variável `PUBLIC_DOMAIN` do .env para manter consistência.

---

## 🧪 Testar HTTPS

### Verificar Certificados

```bash
# Ver informações do certificado
openssl x509 -in certs/cert.pem -noout -text

# Ver datas de validade
openssl x509 -in certs/cert.pem -noout -dates

# Testar HTTPS localmente
curl -k https://localhost/health
curl -k https://localhost:8443/health
```

### Verificar Nginx

```bash
# Status do Nginx
docker compose ps nginx

# Logs do Nginx
docker compose logs nginx

# Testar configuração
docker compose exec nginx nginx -t
```

### Acessar pelo Navegador

1. **Superset:** https://SEU_DOMINIO
2. **Airflow:** https://SEU_DOMINIO:8443
3. **Hop:** https://SEU_DOMINIO:8444

---

## 🔥 Troubleshooting

### Erro: "Certificados não encontrados"

```bash
# Verificar se existem
ls -la certs/

# Gerar novamente
./generate-ssl-cert.sh
```

### Erro: "Nginx não inicia"

```bash
# Ver logs
docker compose logs nginx

# Verificar configuração
docker compose exec nginx nginx -t

# Verificar permissões dos certificados
ls -la certs/
```

### Aviso: "Certificado inválido"

**Para certificados auto-assinados:**
- Isso é esperado. Clique em "Avançado" → "Prosseguir"

**Para Let's Encrypt:**
```bash
# Verificar validade
openssl x509 -in certs/cert.pem -noout -dates

# Se expirado, renovar
./generate-letsencrypt-cert.sh
```

### Erro: "Porta 443 já em uso"

```bash
# Ver o que está usando a porta
sudo lsof -i :443
sudo lsof -i :80

# Parar Apache (se instalado)
sudo systemctl stop apache2
sudo systemctl disable apache2
```

---

## 📚 Próximos Passos

Após configurar HTTPS:

1. **Configure NSG do Azure** (se necessário):
   ```bash
   # Abrir portas HTTPS
   az network nsg rule create --resource-group RG --nsg-name NSG \
     --name HTTPS --priority 300 --destination-port-ranges 443 8443
   ```

2. **Configure Azure Entra SSO:**
   - Leia: [AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)
   - Execute: `./configure-azure-sso.sh`

3. **Inicie a plataforma:**
   ```bash
   docker compose up -d
   ```

---

## 📖 Referências

- [Documentação Nginx](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Azure Entra ID OAuth](https://docs.microsoft.com/azure/active-directory/develop/)
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
