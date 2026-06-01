# 🚀 Guia de Instalação Completo - Do Zero ao Ar

**Plataforma de Dados BI com Apache Airflow, Superset e Hop**

Este guia cobre a instalação completa em um servidor Ubuntu limpo, desde a instalação do sistema operacional até a configuração de SSO com Azure Entra ID.

---

## 📋 Índice

1. [Visão Geral da Arquitetura](#-visão-geral-da-arquitetura)
2. [Pré-requisitos](#-pré-requisitos)
3. [Fase 1: Preparar Servidor Ubuntu](#-fase-1-preparar-servidor-ubuntu-20-minutos)
4. [Fase 2: Instalar Docker](#-fase-2-instalar-docker-15-minutos)
5. [Fase 3: Configurar Cloudflare Tunnel](#-fase-3-configurar-cloudflare-tunnel-15-minutos)
6. [Fase 4: Deploy da Plataforma](#-fase-4-deploy-da-plataforma-10-minutos)
7. [Fase 5: Configurar Azure Entra SSO (Opcional)](#-fase-5-configurar-azure-entra-sso-opcional-20-minutos)
8. [Verificação Final](#-verificação-final)
9. [Próximos Passos](#-próximos-passos)

**⏱️ Tempo Total:** 60-80 minutos

---

## 🏗️ Visão Geral da Arquitetura

### Stack Completa

```
Internet
    ↓
bi.bomgado.com.br (Cloudflare DNS)
    ↓
Cloudflare Edge Network (SSL/TLS + DDoS Protection)
    ↓
Cloudflare Tunnel (conexão encriptada)
    ↓
Servidor Azure Ubuntu 20.04/22.04
    ↓
Nginx Reverse Proxy (HTTP local)
    ↓
Docker Compose (13 containers)
    ↓
┌──────────────┬──────────────┬──────────────┐
│  Superset    │   Airflow    │     Hop      │
│   :8088      │   :8080      │   :8081      │
│              │              │              │
│  (Celery)    │ (Scheduler,  │  (ETL)       │
│              │  Worker,     │              │
│              │  Triggerer)  │              │
└──────┬───────┴──────┬───────┴──────────────┘
       │              │
   ┌───▼────┐    ┌───▼────┐
   │PostgreSQL│  │ Redis  │
   │  :5432  │  │ :6379  │
   └─────────┘  └────────┘
```

### Componentes

| Componente | Versão | Função |
|------------|--------|--------|
| **Ubuntu Server** | 20.04/22.04 | Sistema operacional base |
| **Docker** | 24.x+ | Runtime de containers |
| **Docker Compose** | 2.x+ | Orquestração de containers |
| **Cloudflare Tunnel** | Latest | Proxy seguro sem portas expostas |
| **Nginx** | Alpine | Reverse proxy HTTP local |
| **Apache Airflow** | 2.8.0 | Orquestrador de workflows |
| **Apache Superset** | 3.0.0 | Plataforma de BI |
| **Apache Hop** | 2.7.0 | Engine ETL/ELT |
| **PostgreSQL** | 15 | Banco de metadados |
| **Redis** | 7 | Message broker Celery |

### URLs de Acesso

- **Superset BI:** https://bi.bomgado.com.br
- **Airflow:** https://airflow.bomgado.com.br
- **Hop:** https://hop.bomgado.com.br

---

## 🎯 Pré-requisitos

### Infraestrutura

- [ ] **Azure VM** (ou qualquer servidor com Ubuntu)
  - Mínimo: 4 vCPUs, 8GB RAM, 50GB disk
  - Recomendado: 8 vCPUs, 16GB RAM, 100GB disk
  - IP público ou privado (Cloudflare Tunnel funciona em ambos)
  
- [ ] **Chave SSH** para acesso ao servidor
  - Localização: `C:\Users\camil\.ssh\azuer_teste.pem` (Windows)
  - Permissões: Somente leitura

### Serviços Externos

- [ ] **Conta Cloudflare** (gratuita)
  - Domínio `bomgado.com.br` gerenciado pelo Cloudflare
  - Acesso ao dashboard: https://dash.cloudflare.com

- [ ] **Conta Azure** (opcional, para SSO)
  - Permissão de Application Administrator
  - Acesso ao portal: https://portal.azure.com

### Informações Necessárias

- [ ] IP público do servidor: `172.174.210.23`
- [ ] Usuário SSH: `azureuser`
- [ ] Domínio: `bi.bomgado.com.br`

---

## 🐧 Fase 1: Preparar Servidor Ubuntu (20 minutos)

### Passo 1.1: Conectar ao Servidor

```bash
# Windows (PowerShell)
ssh -i C:\Users\camil\.ssh\azuer_teste.pem azureuser@172.174.210.23

# Linux/Mac
ssh -i ~/.ssh/azuer_teste.pem azureuser@172.174.210.23
```

### Passo 1.2: Atualizar Sistema

```bash
# Atualizar lista de pacotes
sudo apt update

# Upgrade de segurança
sudo apt upgrade -y

# Instalar ferramentas básicas
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release
```

### Passo 1.3: Configurar Timezone

```bash
# Configurar timezone para São Paulo
sudo timedatectl set-timezone America/Sao_Paulo

# Verificar
timedatectl
```

**Saída esperada:**
```
Time zone: America/Sao_Paulo (-03, -0300)
```

### Passo 1.4: Configurar Git (para versionamento)

```bash
git config --global user.name "Camil Teixeira"
git config --global user.email "camilteixeira@bomgado.com.br"
```

### Passo 1.5: Desabilitar Firewall UFW (Cloudflare Tunnel não precisa)

```bash
# Verificar status
sudo ufw status

# Se ativo, desabilitar (Cloudflare Tunnel não usa portas públicas)
sudo ufw disable
```

---

## 🐳 Fase 2: Instalar Docker (15 minutos)

### Passo 2.1: Remover Versões Antigas

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
```

### Passo 2.2: Adicionar Repositório Docker

```bash
# Adicionar chave GPG oficial
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurar repositório
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Passo 2.3: Instalar Docker

```bash
# Atualizar apt
sudo apt update

# Instalar Docker Engine
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verificar instalação
docker --version
docker compose version
```

**Saída esperada:**
```
Docker version 24.x.x
Docker Compose version v2.x.x
```

### Passo 2.4: Configurar Permissões Docker

```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Aplicar mudanças (re-login)
newgrp docker

# Testar sem sudo
docker ps
```

### Passo 2.5: Habilitar Docker no Boot

```bash
sudo systemctl enable docker
sudo systemctl enable containerd

# Verificar status
sudo systemctl status docker
```

---

## ☁️ Fase 3: Configurar Cloudflare Tunnel (15 minutos)

### Passo 3.1: Criar Tunnel no Cloudflare Dashboard

1. Acesse https://dash.cloudflare.com
2. Selecione domínio: **bomgado.com.br**
3. Menu: **Zero Trust** → **Access** → **Tunnels**
4. Clique **Create a tunnel**
5. Nome: `bi-bomgado-data-platform`
6. Clique **Save tunnel**

### Passo 3.2: Copiar Token do Tunnel

Na tela seguinte, você verá:

```bash
cloudflared service install eyJhIjoiLi4uIiwidCI6Ii4uLiIsInMiOiIuLi4ifQ==
```

**⚠️ COPIE O TOKEN COMPLETO!**

### Passo 3.3: Configurar Public Hostnames

No dashboard do tunnel, adicione 3 hostnames:

| Subdomain | Domain | Type | URL |
|-----------|--------|------|-----|
| `bi` | `bomgado.com.br` | HTTP | `localhost:80` |
| `airflow` | `bomgado.com.br` | HTTP | `localhost:8080` |
| `hop` | `bomgado.com.br` | HTTP | `localhost:8081` |

Clique **Save tunnel**.

### Passo 3.4: Instalar cloudflared no Servidor

```bash
# Baixar e instalar cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Verificar
cloudflared --version
```

### Passo 3.5: Instalar e Iniciar Tunnel

```bash
# Substituir <SEU_TOKEN> pelo token copiado
sudo cloudflared service install <SEU_TOKEN>

# Iniciar serviço
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Verificar status
sudo systemctl status cloudflared
```

**Status esperado:**
```
● cloudflared.service - Cloudflare Tunnel
   Active: active (running)
```

### Passo 3.6: Verificar Logs

```bash
sudo journalctl -u cloudflared -n 20
```

**Logs esperados:**
```
INF Connection registered connIndex=0
INF Connection registered connIndex=1
```

---

## 🚀 Fase 4: Deploy da Plataforma (10 minutos)

### Passo 4.1: Clonar Repositório

```bash
cd ~
git clone <URL_DO_REPOSITORIO> superset_airflow_env
cd superset_airflow_env
```

### Passo 4.2: Configurar Variáveis de Ambiente

```bash
# Copiar template
cp .env.example .env

# Editar .env
nano .env
```

**Configure as variáveis:**

```bash
# ============================================
# CONFIGURAÇÕES GERAIS
# ============================================
PUBLIC_DOMAIN=bi.bomgado.com.br
TIMEZONE=America/Sao_Paulo

# ============================================
# SEGURANÇA - ALTERE TODOS!
# ============================================
POSTGRES_PASSWORD=SuaSenhaPostgres123!
REDIS_PASSWORD=SuaSenhaRedis123!
SUPERSET_SECRET_KEY=<GERAR_CHAVE_MINIMO_42_CARACTERES>
AIRFLOW__CORE__FERNET_KEY=<GERAR_CHAVE_FERNET>
AIRFLOW__WEBSERVER__SECRET_KEY=<GERAR_CHAVE_32_CARACTERES>

# ============================================
# SSL/TLS - NÃO NECESSÁRIO (Cloudflare gerencia)
# ============================================
# SSL_CERT_PATH=./certs/cert.pem
# SSL_KEY_PATH=./certs/key.pem
```

### Passo 4.3: Gerar Chaves de Segurança

```bash
# Gerar Fernet Key (Airflow)
docker run --rm python:3.11-slim sh -c \
  "pip install -q cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"

# Copie o output e cole em AIRFLOW__CORE__FERNET_KEY no .env
```

**Exemplo de output:**
```
K8dOJ0vN2xQ7_wZ5yH3mP9bR4cT6aU1sF8gL0eI2jV4=
```

Repita para gerar outras chaves:

```bash
# Secret Key genérica (42+ caracteres)
openssl rand -base64 42

# Copie para SUPERSET_SECRET_KEY e AIRFLOW__WEBSERVER__SECRET_KEY
```

### Passo 4.4: Criar Estrutura de Diretórios

```bash
# Criar diretórios necessários
mkdir -p airflow/{logs,dags,plugins,config}
mkdir -p superset/{config,data}
mkdir -p hop/{config,projects,metadata}
mkdir -p postgres/init-scripts
mkdir -p shared/data
mkdir -p nginx

# Ajustar permissões
chmod -R 755 airflow superset hop postgres shared nginx
chmod -R 777 airflow/logs

# Permissões Airflow (UID 50000)
sudo chown -R 50000:0 airflow/

# Executáveis
chmod +x *.sh postgres/init-scripts/*.sh 2>/dev/null || true
```

### Passo 4.5: Iniciar Plataforma

```bash
# Baixar imagens Docker (pode levar 5-10 minutos)
docker compose pull

# Iniciar containers
docker compose up -d

# Aguardar inicialização (2-3 minutos)
sleep 120

# Verificar status
docker compose ps
```

**Todos os containers devem estar `healthy` ou `running`.**

### Passo 4.6: Verificar Logs

```bash
# Logs gerais
docker compose logs -f

# Logs específicos
docker compose logs -f superset
docker compose logs -f airflow-webserver
docker compose logs -f nginx
```

---

## 🧪 Verificação de Funcionamento

### Teste 1: Verificar Containers

```bash
docker compose ps
```

**Esperado:** Todos com status `running` ou `healthy`.

### Teste 2: Verificar Cloudflare Tunnel

```bash
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -n 10
```

**Esperado:** `active (running)` com 2+ conexões registradas.

### Teste 3: Testar Localmente

```bash
# Superset
curl -I http://localhost:80

# Airflow
curl -I http://localhost:8080

# Hop
curl -I http://localhost:8081
```

**Esperado:** HTTP 200 ou 302 (redirect para login).

### Teste 4: Testar via Cloudflare

Abra no navegador:

- **Superset:** https://bi.bomgado.com.br
- **Airflow:** https://airflow.bomgado.com.br
- **Hop:** https://hop.bomgado.com.br

**✅ Deve abrir telas de login com HTTPS válido!**

### Credenciais Padrão

| Serviço | Usuário | Senha |
|---------|---------|-------|
| **Superset** | admin | admin123 |
| **Airflow** | admin | admin123 |
| **Hop** | cluster | cluster |

**⚠️ ALTERE AS SENHAS após primeiro login!**

---

## 🔐 Fase 5: Configurar Azure Entra SSO (Opcional - 20 minutos)

Se quiser autenticação com Azure AD:

👉 **Guia completo:** [AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)

### Redirect URIs para Azure

**Superset:**
```
https://bi.bomgado.com.br/oauth-authorized/azure
```

**Airflow:**
```
https://airflow.bomgado.com.br/oauth-authorized/azure
```

---

## ✅ Verificação Final

### Checklist Completo

- [ ] Ubuntu atualizado e configurado
- [ ] Docker e Docker Compose instalados
- [ ] Cloudflare Tunnel conectado e ativo
- [ ] 13 containers rodando sem erros
- [ ] Superset acessível via https://bi.bomgado.com.br
- [ ] Airflow acessível via https://airflow.bomgado.com.br
- [ ] Hop acessível via https://hop.bomgado.com.br
- [ ] HTTPS válido (certificado Cloudflare)
- [ ] Login funcional em todas as aplicações

### Comandos Úteis

```bash
# Status geral
docker compose ps

# Logs em tempo real
docker compose logs -f

# Reiniciar tudo
docker compose restart

# Parar tudo
docker compose down

# Iniciar tudo
docker compose up -d

# Ver uso de recursos
docker stats

# Cloudflare Tunnel
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f
```

---

## 🎓 Próximos Passos

### 1. Segurança

- [ ] Alterar senhas padrão (admin/admin123)
- [ ] Configurar Azure Entra SSO
- [ ] Habilitar Cloudflare Access (Zero Trust)
- [ ] Configurar backup automatizado

### 2. Configuração

- [ ] Criar usuários e permissões
- [ ] Configurar conexões de dados no Superset
- [ ] Criar DAGs no Airflow
- [ ] Desenvolver pipelines no Hop

### 3. Monitoramento

- [ ] Configurar alertas no Airflow
- [ ] Monitorar uso de recursos (docker stats)
- [ ] Configurar logs centralizados
- [ ] Cloudflare Analytics

### 4. Backup

```bash
# Backup do banco PostgreSQL
docker compose exec postgres pg_dumpall -U airflow > backup_$(date +%Y%m%d).sql

# Backup de configurações
tar -czf backup_configs_$(date +%Y%m%d).tar.gz \
  .env \
  airflow/dags \
  superset/config \
  hop/projects
```

---

## 📚 Documentação Adicional

- **[README.md](README.md)** - Visão geral do projeto
- **[QUICKSTART.md](QUICKSTART.md)** - Início rápido (resumido)
- **[CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)** - Detalhes do Cloudflare Tunnel
- **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** - Configurar SSO com Azure
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solução de problemas
- **[CHECKLIST.md](CHECKLIST.md)** - Checklist detalhado
- **[HOP_GUIDE.md](hop/HOP_GUIDE.md)** - Guia do Apache Hop

---

## 🆘 Suporte

### Problemas Comuns

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

**Erro de permissão Airflow:**
```bash
sudo chown -R 50000:0 airflow/
chmod -R 777 airflow/logs
```

**502 Bad Gateway:**
- Verificar se containers estão rodando: `docker compose ps`
- Verificar logs do Nginx: `docker compose logs nginx`
- Testar localmente: `curl http://localhost`

---

**🎉 Instalação Completa! Plataforma de Dados no ar com segurança Cloudflare!**
