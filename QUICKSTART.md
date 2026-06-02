# ⚡ Início Rápido

**Escolha o método ideal para sua situação:**

| Situação | Método | Tempo | Guia |
|----------|--------|-------|------|
| 🆕 **Servidor Ubuntu limpo** | **Instalação Automatizada** ⚡ | **15-20 min** | **[AUTOMATED_INSTALL.md](AUTOMATED_INSTALL.md)** |
| 🖥️ Servidor Ubuntu limpo (manual) | Passo a Passo Manual | 60-80 min | [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) |
| ✅ Docker já instalado | Início Rápido | 5 min | Este guia |

> 💡 **NOVO!** Script de instalação 100% automatizado disponível - recomendado para novos deployments.

---

## 🎯 Se Docker JÁ está Instalado (5 minutos)

Guia super rápido para quem tem pressa e já conhece Docker.

> ☁️ **RECOMENDADO:** Use Cloudflare Tunnel para acesso seguro sem expor portas

---

## 🎯 Cenário 1: Ubuntu Server do Zero

**Tem Ubuntu Server recém-instalado?**

👉 **Consulte: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Guia completo passo a passo (60 min)

---

## 🎯 Cenário 2: Docker já Instalado + Cloudflare Tunnel

### 1. Configure Cloudflare Tunnel

**No Cloudflare Dashboard:**
1. Acesse https://dash.cloudflare.com
2. Zero Trust → Tunnels → Create a tunnel
3. Nome: `bi-bomgado-data-platform`
4. Copie o token

**No Servidor:**
```bash
# Instalar cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Configurar tunnel (cole seu token)
sudo cloudflared service install <SEU_TOKEN>
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

**Configure Public Hostnames no Cloudflare:**
- `bi.bomgado.com.br` → HTTP → `localhost:80`
- `airflow.bomgado.com.br` → HTTP → `localhost:8080`
- `hop.bomgado.com.br` → HTTP → `localhost:8081`

### 2. Clone o repositório

```bash
git clone <url-repositorio>
cd superset_airflow_env
```

### 3. Configure ambiente

```bash
# Copiar template
cp .env.example .env

# Edite o .env
nano .env
```

**Configure no .env:**
```bash
PUBLIC_DOMAIN=bi.bomgado.com.br
POSTGRES_PASSWORD=SuaSenhaSegura123!
REDIS_PASSWORD=OutraSenhaSegura123!
```

### 4. Gerar chaves de segurança

```bash
# Fernet Key para Airflow
docker run --rm python:3.11-slim sh -c "pip install -q cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"

# Secret Key genérica (42+ caracteres)
openssl rand -base64 42
```

Cole as chaves geradas no `.env`:
- `AIRFLOW__CORE__FERNET_KEY=<chave_fernet>`
- `SUPERSET_SECRET_KEY=<secret_key>`
- `AIRFLOW__WEBSERVER__SECRET_KEY=<secret_key>`

### 5. Ajuste permissões (Linux/Mac)

```bash
chmod +x *.sh postgres/init-scripts/*.sh
mkdir -p airflow/logs
sudo chown -R 50000:0 airflow/
chmod -R 777 airflow/logs
```

**Windows**: Pule esta etapa.

### 6. Inicialize

```bash
# Iniciar plataforma
docker compose up -d

# Aguardar 2-3 minutos
docker compose logs -f
```

### 7. Acesse

- **Superset:** https://bi.bomgado.com.br (admin/admin123)
- **Airflow:** https://airflow.bomgado.com.br (admin/admin123)
- **Hop:** https://hop.bomgado.com.br (cluster/cluster)

**✅ HTTPS automático via Cloudflare!**

---

## 🎯 Cenário 3: Sem Cloudflare (Acesso Local)

Se não quiser usar Cloudflare Tunnel:

```bash
# 1. Clone
git clone <url-repositorio>
cd superset_airflow_env

# 2. Configure .env
cp .env.example .env
nano .env  # Configure senhas e chaves

# 3. Inicie
docker compose up -d
```

**Acesse localmente:**
- Superset: http://localhost:80
- Airflow: http://localhost:8080
- Hop: http://localhost:8081

> ⚠️ **Sem Cloudflare:** Você precisa expor portas no firewall/NSG e configurar SSL manualmente  
> 📖 Veja: [HTTPS_SETUP.md](HTTPS_SETUP.md) e [AZURE_SETUP.md](AZURE_SETUP.md)

---

## ✅ Verificação Rápida

```bash
# Status dos containers
docker compose ps

# Status do Cloudflare Tunnel (se configurado)
sudo systemctl status cloudflared

# Logs em tempo real
docker compose logs -f nginx superset airflow-webserver

# Testar localmente
curl http://localhost
```

👉 **[CHECKLIST.md](CHECKLIST.md)** - Verificação completa

---

## 📚 Documentação Completa

- **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Guia completo de instalação do zero
- **[README.md](README.md)** - Documentação detalhada
- **[CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)** - Detalhes do Cloudflare Tunnel
- **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** - Setup Ubuntu do zero
- **[HTTPS_SETUP.md](HTTPS_SETUP.md)** - Configuração SSL/TLS (sem Cloudflare)
- **[AZURE_SETUP.md](AZURE_SETUP.md)** - Setup Azure VM
- **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** - SSO com Azure Entra
- **[CHECKLIST.md](CHECKLIST.md)** - Checklist completo

---

## 🆘 Problemas?

**Containers não iniciam:**
```bash
docker compose logs <nome_container>
docker compose restart <nome_container>
```

**Cloudflare Tunnel offline:**
```bash
sudo systemctl restart cloudflared
sudo journalctl -u cloudflared -n 50
```

**502 Bad Gateway:**
```bash
# Verificar containers
docker compose ps

# Verificar Nginx
docker compose logs nginx

# Testar localmente
curl http://localhost
```

👉 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Soluções para problemas comuns
- **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** - Guia do Hop

---

## 🚀 Comandos Úteis

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f

# Parar
docker compose stop

# Iniciar
docker compose start

# Reiniciar
docker compose restart

# Destruir tudo (cuidado!)
docker compose down -v
```

---

**Pronto! Ambiente configurado em minutos!** ⚡
