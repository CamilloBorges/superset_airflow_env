# ⚡ Início Rápido - 5 Minutos

Guia super rápido para quem tem pressa e já conhece Docker.

> 🔒 **ATENÇÃO:** Esta plataforma usa **HTTPS por padrão** via Nginx reverse proxy.

---

## 🎯 Cenário 1: Ubuntu Server do Zero

**Tem Ubuntu Server recém-instalado?**

👉 **Consulte: [UBUNTU_SETUP.md](UBUNTU_SETUP.md)** - Guia completo passo a passo

---

## 🎯 Cenário 2: Docker já Instalado

### 1. Clone o repositório

```bash
git clone <url-repositorio>
cd superset_airflow_env
```

### 2. Configure ambiente

```bash
# Copiar template
cp .env.example .env

# Edite o .env e configure:
nano .env
```

**Configure no .env:**
- `PUBLIC_DOMAIN` - Seu IP público ou domínio (ex: `172.174.210.23` ou `dados.empresa.com`)
- Senhas: `POSTGRES_PASSWORD`, `REDIS_PASSWORD`
- Chaves de segurança (veja passo 3)

### 3. Gerar chaves de segurança

```bash
# Opção A: Com Python local
pip3 install cryptography
python3 generate_secrets.py

# Opção B: Com Docker (sem instalar nada)
docker run --rm python:3.11-slim sh -c "pip install -q cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
```

Cole as chaves geradas no `.env`.

### 4. Gerar certificados SSL

```bash
# Opção A: Certificado auto-assinado (desenvolvimento/teste)
./generate-ssl-cert.sh

# Opção B: Let's Encrypt (produção com domínio)
./generate-letsencrypt-cert.sh
```

> 💡 Para mais detalhes: [HTTPS_SETUP.md](HTTPS_SETUP.md)

### 5. Ajuste permissões (Linux/Mac)

```bash
chmod +x quick-start.sh generate-ssl-cert.sh generate-letsencrypt-cert.sh
chmod +x postgres/init-scripts/*.sh
sudo chown -R 50000:0 airflow/
chmod -R 777 airflow/logs
```

**Windows**: Pule esta etapa.

### 6. Inicialize

```bash
# Linux/Mac (script automático com SSL)
./quick-start.sh

# Ou manualmente
docker compose up -d
```

### 7. Aguarde 2-5 minutos e acesse

- **Superset**: https://SEU_DOMINIO:443 (admin/admin123)
- **Airflow**: https://SEU_DOMINIO:8443 (admin/admin123)
- **Hop**: https://SEU_DOMINIO:8444 (cluster/cluster)

> 💡 Substitua `SEU_DOMINIO` pelo valor de `PUBLIC_DOMAIN` do .env

⚠️ **Certificados auto-assinados:** Navegador mostrará aviso. Clique "Avançado" → "Prosseguir".

---

## ✅ Verificação Rápida

```bash
# Status
docker compose ps

# Logs
docker compose logs -f nginx superset airflow-webserver

# Testar HTTPS
curl -k https://localhost/health
curl -k https://localhost:8443/health
```

👉 **[CHECKLIST.md](CHECKLIST.md)** - Verificação completa

---

## 🌩️ Usando Azure?

**Configure NSG** para permitir tráfego HTTPS:

```bash
# Abrir portas
az network nsg rule create --resource-group RG --nsg-name NSG \
  --name HTTPS --priority 300 \
  --destination-port-ranges 443 8443 8444 --access Allow
```

👉 **[AZURE_SETUP.md](AZURE_SETUP.md)** - Configuração completa Azure

---

## 🔐 Quer SSO com Azure Entra ID?

👉 **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** - Configuração de SSO

---

## 🆘 Problemas?

👉 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Soluções para problemas comuns

---

## 📚 Documentação Completa

- **[README.md](README.md)** - Documentação detalhada
- **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** - Setup Ubuntu do zero
- **[HTTPS_SETUP.md](HTTPS_SETUP.md)** - Configuração SSL/TLS
- **[AZURE_SETUP.md](AZURE_SETUP.md)** - Setup Azure
- **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** - SSO com Azure Entra
- **[CHECKLIST.md](CHECKLIST.md)** - Checklist completo
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
