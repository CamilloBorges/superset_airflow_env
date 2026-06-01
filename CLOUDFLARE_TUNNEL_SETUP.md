# ☁️ Guia de Configuração - Cloudflare Tunnel

Este guia configura **Cloudflare Tunnel** para expor a plataforma de dados com segurança através do domínio **bi.bomgado.com.br**, sem necessidade de abrir portas no firewall/NSG.

---

## 🎯 Visão Geral

### O que é Cloudflare Tunnel?

Cloudflare Tunnel cria uma conexão segura e encriptada entre seu servidor e a rede Cloudflare, **sem expor portas públicas**. Todo o tráfego passa pela rede global da Cloudflare.

### Arquitetura com Cloudflare Tunnel

```
Internet
    ↓
bi.bomgado.com.br (Cloudflare DNS)
    ↓
Cloudflare Edge Network (SSL/TLS)
    ↓
Cloudflare Tunnel (encriptado)
    ↓
Servidor Azure (SEM portas públicas)
    ↓
Nginx (HTTP local - porta 80, 8080, 8081)
    ↓
┌──────────────┬──────────────┬──────────────┐
│  Superset    │   Airflow    │     Hop      │
│   :8088      │   :8080      │   :8081      │
└──────────────┴──────────────┴──────────────┘
```

### Benefícios

✅ **Sem exposição de portas** - NSG não precisa abrir 443, 8443, 8444  
✅ **SSL/TLS automático** - Cloudflare gerencia certificados  
✅ **DDoS protection** - Proteção nativa da Cloudflare  
✅ **CDN global** - Cache e performance  
✅ **Zero Trust** - Controle de acesso integrado  
✅ **IP estático não necessário** - Tunnel funciona mesmo com IP dinâmico

---

## 📋 Pré-requisitos

- [ ] Conta Cloudflare (gratuita) - [cloudflare.com](https://cloudflare.com)
- [ ] Domínio `bomgado.com.br` gerenciado pelo Cloudflare
- [ ] Servidor Ubuntu com Docker instalado
- [ ] Acesso SSH ao servidor Azure

---

## 🚀 Parte 1: Configurar Cloudflare Dashboard

### Passo 1.1: Criar Tunnel no Cloudflare

1. Acesse [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Selecione seu domínio: **bomgado.com.br**
3. Menu lateral: **Zero Trust** → **Access** → **Tunnels**
4. Clique **Create a tunnel**
5. Nome do tunnel: `bi-bomgado-data-platform`
6. Clique **Save tunnel**

### Passo 1.2: Anotar Token do Tunnel

Na tela seguinte, você verá um comando como:

```bash
cloudflared service install <TOKEN_AQUI>
```

**⚠️ COPIE E SALVE O TOKEN!** Você precisará dele no servidor.

Exemplo de token:
```
eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwIiwidCI6IjEyMzQ1Njc4OTAiLCJzIjoiYWJjZGVmZ2gifQ==
```

### Passo 1.3: Configurar Public Hostnames

Ainda no dashboard do tunnel, configure os hostnames:

#### **Hostname 1: Superset (porta 443)**

- **Subdomain:** `bi`
- **Domain:** `bomgado.com.br`
- **Type:** HTTP
- **URL:** `nginx:80` (ou `localhost:80` se cloudflared rodar no host)

#### **Hostname 2: Airflow (porta 8443)**

- **Subdomain:** `airflow`
- **Domain:** `bomgado.com.br`
- **Type:** HTTP
- **URL:** `nginx:8080` (ou `localhost:8080`)

#### **Hostname 3: Hop (porta 8081)**

- **Subdomain:** `hop`
- **Domain:** `bomgado.com.br`
- **Type:** HTTP
- **URL:** `nginx:8081` (ou `localhost:8081`)

Clique **Save tunnel** para aplicar as configurações.

---

## 🐧 Parte 2: Instalar cloudflared no Servidor Ubuntu

### Passo 2.1: Conectar ao Servidor

```bash
ssh -i ~/.ssh/azuer_teste.pem azureuser@172.174.210.23
```

### Passo 2.2: Instalar cloudflared

```bash
# Baixar pacote .deb
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# Instalar
sudo dpkg -i cloudflared-linux-amd64.deb

# Verificar instalação
cloudflared --version
```

**Saída esperada:**
```
cloudflared version 2024.x.x
```

### Passo 2.3: Autenticar e Instalar Tunnel

Use o token copiado no Passo 1.2:

```bash
# Substituir <SEU_TOKEN> pelo token real
sudo cloudflared service install <SEU_TOKEN>
```

**Exemplo:**
```bash
sudo cloudflared service install eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwIiwidCI6IjEyMzQ1Njc4OTAiLCJzIjoiYWJjZGVmZ2gifQ==
```

### Passo 2.4: Iniciar e Habilitar Serviço

```bash
# Iniciar serviço
sudo systemctl start cloudflared

# Habilitar auto-start
sudo systemctl enable cloudflared

# Verificar status
sudo systemctl status cloudflared
```

**Saída esperada:**
```
● cloudflared.service - Cloudflare Tunnel
   Loaded: loaded (/etc/systemd/system/cloudflared.service)
   Active: active (running) since ...
```

### Passo 2.5: Verificar Logs

```bash
# Ver logs em tempo real
sudo journalctl -u cloudflared -f

# Últimas 50 linhas
sudo journalctl -u cloudflared -n 50
```

**Logs esperados:**
```
INF Connection registered connIndex=0 location=ABC
INF Connection registered connIndex=1 location=DEF
INF Registered tunnel connection
```

---

## 🔧 Parte 3: Configurar Nginx para Cloudflare

### Passo 3.1: Atualizar nginx.conf

Edite o arquivo Nginx para usar HTTP local (Cloudflare gerencia HTTPS):

```bash
cd ~/superset_airflow_env
nano nginx/nginx.conf
```

**Configuração para Cloudflare:**

```nginx
# Upstream backends
upstream superset_backend {
    server superset:8088;
}

upstream airflow_backend {
    server airflow-webserver:8080;
}

upstream hop_backend {
    server hop-server:8081;
}

# Superset HTTP (porta 80)
server {
    listen 80;
    server_name bi.bomgado.com.br;

    # Aceitar apenas tráfego do Cloudflare
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    real_ip_header CF-Connecting-IP;

    location / {
        proxy_pass http://superset_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # OAuth callback do Superset
    location /oauth-authorized/azure {
        proxy_pass http://superset_backend/oauth-authorized/azure;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# Airflow HTTP (porta 8080)
server {
    listen 8080;
    server_name airflow.bomgado.com.br;

    # IPs do Cloudflare
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    real_ip_header CF-Connecting-IP;

    location / {
        proxy_pass http://airflow_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /oauth-authorized/azure {
        proxy_pass http://airflow_backend/oauth-authorized/azure;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# Hop HTTP (porta 8081)
server {
    listen 8081;
    server_name hop.bomgado.com.br;

    location / {
        proxy_pass http://hop_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
    }
}
```

### Passo 3.2: Atualizar docker-compose.yml

O Nginx agora usa HTTP (não HTTPS):

```yaml
nginx:
  image: nginx:alpine
  container_name: nginx-proxy
  ports:
    - "80:80"       # Superset
    - "8080:8080"   # Airflow
    - "8081:8081"   # Hop
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
  depends_on:
    - superset
    - airflow-webserver
    - hop-server
  networks:
    - data-platform-network
  restart: unless-stopped
```

---

## 🧪 Parte 4: Testar Configuração

### Passo 4.1: Reiniciar Nginx

```bash
docker compose restart nginx
```

### Passo 4.2: Verificar Tunnel

```bash
# Status do cloudflared
sudo systemctl status cloudflared

# Logs
sudo journalctl -u cloudflared -n 20
```

### Passo 4.3: Testar DNS

```bash
# Verificar resolução DNS
nslookup bi.bomgado.com.br
nslookup airflow.bomgado.com.br
nslookup hop.bomgado.com.br
```

Todos devem apontar para IPs da Cloudflare (104.x.x.x ou 172.x.x.x).

### Passo 4.4: Testar Acesso

Abra no navegador:

- **Superset:** https://bi.bomgado.com.br
- **Airflow:** https://airflow.bomgado.com.br
- **Hop:** https://hop.bomgado.com.br

**✅ HTTPS automático com certificado Cloudflare!**

---

## 🔐 Parte 5: Configurar Azure Entra SSO

Com Cloudflare Tunnel, os redirect URIs serão:

### Superset

```
https://bi.bomgado.com.br/oauth-authorized/azure
```

### Airflow

```
https://airflow.bomgado.com.br/oauth-authorized/azure
```

Atualize os App Registrations no Azure Portal com essas URIs.

---

## 🔥 Troubleshooting

### Erro: "Tunnel não conecta"

```bash
# Verificar logs
sudo journalctl -u cloudflared -n 50

# Reinstalar tunnel
sudo cloudflared service uninstall
sudo cloudflared service install <SEU_TOKEN>
sudo systemctl restart cloudflared
```

### Erro: "502 Bad Gateway"

```bash
# Verificar se containers estão rodando
docker compose ps

# Verificar logs do Nginx
docker compose logs nginx

# Verificar se Nginx está acessível localmente
curl http://localhost
```

### Erro: "DNS não resolve"

- Aguarde 5-10 minutos para propagação DNS
- Limpe cache DNS: `ipconfig /flushdns` (Windows) ou `sudo systemd-resolve --flush-caches` (Linux)

### Erro: "Cloudflare Tunnel offline"

```bash
# Verificar serviço
sudo systemctl status cloudflared

# Reiniciar
sudo systemctl restart cloudflared

# Verificar conectividade
ping cloudflare.com
```

---

## 🛡️ Segurança Adicional

### Restringir Acesso ao Nginx

Edite `nginx.conf` para aceitar APENAS tráfego do Cloudflare:

```nginx
# No topo de cada server block
deny all;
allow 173.245.48.0/20;
allow 103.21.244.0/22;
allow 103.22.200.0/22;
allow 103.31.4.0/22;
allow 141.101.64.0/18;
allow 108.162.192.0/18;
allow 190.93.240.0/20;
allow 188.114.96.0/20;
allow 197.234.240.0/22;
allow 198.41.128.0/17;
allow 162.158.0.0/15;
allow 104.16.0.0/13;
allow 104.24.0.0/14;
allow 172.64.0.0/13;
allow 131.0.72.0/22;
deny all;
```

### Cloudflare Access (Zero Trust)

Proteja aplicações com autenticação adicional:

1. Cloudflare Dashboard → **Zero Trust** → **Access** → **Applications**
2. Crie política para `bi.bomgado.com.br`
3. Configure regras (ex: apenas emails `@bomgado.com.br`)

---

## 📚 Próximos Passos

1. ✅ Cloudflare Tunnel configurado
2. 📝 Configure Azure Entra SSO: [AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)
3. 🔄 Configure renovação automática (Cloudflare gerencia SSL automaticamente)

---

## 📖 Referências

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cloudflared GitHub](https://github.com/cloudflare/cloudflared)
- [Cloudflare IP Ranges](https://www.cloudflare.com/ips/)
