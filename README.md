# Plataforma de Dados Empresarial

Ambiente completo de Business Intelligence e Engenharia de Dados com:
- **Apache Superset 6.1.0** - Visualização e BI
- **Apache Airflow 2.8.0** - Orquestração de workflows
- **Apache Hop 2.7.0** - ETL/ELT
- **PostgreSQL 15** - Banco de metadados
- **Redis 7** - Cache e message broker
- **Nginx** - Reverse proxy
- **Cloudflare Tunnel** - Acesso seguro HTTPS
- **Azure Entra ID** - SSO obrigatório

## 🚀 Instalação Automatizada

```bash
# 1. Clone o repositório
git clone https://github.com/CamilloBorges/superset_airflow_env.git data-platform
cd data-platform

# 2. Configure variáveis (edite .env com seus valores Azure)
cp .env.example .env
nano .env

# 3. Execute instalação automatizada
./install.sh
```

**Tempo total**: ~20 minutos  
**Documentação completa**: [INSTALL.md](INSTALL.md)

---

## 📋 Pré-requisitos

### Servidor
- Ubuntu 24.04 LTS (ou 22.04)
- 8GB RAM mínimo (16GB recomendado)
- 30GB disco
- Acesso SSH com sudo

### Azure Portal
- Conta Azure com permissão para criar App Registrations
- Tenant ID do Azure Entra ID
- 2 App Registrations criados (Superset + Airflow)

### Cloudflare
- Conta Cloudflare
- Domínio configurado no Cloudflare
- Tunnel criado e token gerado

---

## 🏗️ Arquitetura

```
Internet (HTTPS)
    ↓
Cloudflare Edge (SSL/TLS + DDoS Protection)
    ↓
Cloudflare Tunnel (encrypted, no public ports)
    ↓
Ubuntu Server Azure VM
    ↓
Nginx Reverse Proxy (HTTP local)
    ↓
┌─────────────┬─────────────┬─────────────┐
│  Superset   │   Airflow   │     Hop     │
│   :8088     │   :8080     │   :8081     │
└─────────────┴─────────────┴─────────────┘
       ↓               ↓
  PostgreSQL         Redis
    :5432           :6379
```

**Acessos:**
- Superset: https://bi.bomgado.com.br
- Airflow: https://airflow.bomgado.com.br  
- Hop: https://hop.bomgado.com.br

---

## 📁 Estrutura do Projeto

```
data-platform/
├── .env                          # Variáveis de ambiente (NÃO commitado)
├── .env.example                  # Template de variáveis
├── docker-compose.yml            # Orquestração de containers
├── install.sh                    # Script de instalação automatizada
├── INSTALL.md                    # Documentação de instalação
├── airflow/
│   ├── config/
│   │   └── webserver_config.py   # SSO Azure configurado
│   ├── dags/                     # DAGs do Airflow
│   ├── logs/                     # Logs do Airflow
│   └── plugins/                  # Plugins customizados
├── superset/
│   ├── Dockerfile                # Superset 6.1.0 + authlib + psycopg2
│   ├── config/
│   │   └── superset_config.py    # SSO Azure + Redis session
│   └── data/                     # Dados persistentes
├── hop/
│   ├── projects/                 # Projetos Hop
│   └── metadata/                 # Metadata Hop
├── nginx/
│   └── nginx.conf                # Configuração Nginx
├── postgres/
│   └── init-scripts/
│       └── 01-init-databases.sh  # Criação de DBs
└── shared/
    └── data/                     # Dados compartilhados
```

---

## 🔐 Configuração Azure SSO

### 1. Criar App Registrations

**Superset:**
- Nome: `bi-bomgado-superset`
- Redirect URI: `https://bi.bomgado.com.br/oauth-authorized/azure`
- Scopes: `openid`, `email`, `profile`, `User.Read`

**Airflow:**
- Nome: `airflow-bomgado`
- Redirect URI: `https://airflow.bomgado.com.br/oauth-authorized/azure`
- Scopes: `openid`, `email`, `profile`, `User.Read`

### 2. Gerar Client Secrets

Para cada App Registration:
1. Certificates & secrets → New client secret
2. Copiar o Value (não o Secret ID)
3. Adicionar ao `.env`

### 3. Configurar .env

```bash
AZURE_TENANT_ID=0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035
AZURE_SUPERSET_CLIENT_ID=<Application ID do Superset>
AZURE_SUPERSET_CLIENT_SECRET=<Secret Value do Superset>
AZURE_AIRFLOW_CLIENT_ID=<Application ID do Airflow>
AZURE_AIRFLOW_CLIENT_SECRET=<Secret Value do Airflow>
```

---

## 🔧 Comandos Úteis

```bash
# Ver status de todos os serviços
docker compose ps

# Ver logs em tempo real
docker compose logs -f superset
docker compose logs -f airflow-webserver

# Reiniciar um serviço
docker compose restart superset

# Parar tudo
docker compose down

# Parar e remover volumes (CUIDADO: apaga dados!)
docker compose down -v

# Rebuild de imagens customizadas
docker compose build superset-init

# Acessar shell de um container
docker compose exec superset bash
docker compose exec airflow-webserver bash
```

---

## 🐛 Troubleshooting

### OAuth não funciona

1. Verifique variáveis Azure no `.env`
2. Confirme Redirect URIs no Azure Portal
3. Verifique logs: `docker compose logs superset | grep -i oauth`
4. Limpe cookies do navegador
5. Verifique se Cloudflare Tunnel está ativo

### Serviço não inicia

```bash
# Ver logs detalhados
docker compose logs <serviço>

# Verificar healthcheck
docker compose ps

# Reiniciar ordem correta
docker compose up -d postgres redis
sleep 30
docker compose up -d
```

### Migrations falhando

```bash
# Superset
docker compose exec superset superset db upgrade
docker compose exec superset superset init

# Airflow
docker compose exec airflow-webserver airflow db migrate
```

---

## 📊 Gestão de Usuários

**Roles Superset:**
- **Admin**: Acesso total
- **Alpha**: Criar dashboards e datasets
- **Gamma**: Visualizar dashboards (padrão novo usuário)
- **Public**: Visualização pública (desabilitado)

**Roles Airflow:**
- **Admin**: Acesso total
- **Op**: Executar e gerenciar DAGs
- **User**: Visualizar e executar DAGs
- **Viewer**: Visualização read-only (padrão novo usuário)

**Primeiro login SSO**: Usuário criado automaticamente com role padrão.  
**Elevar permissões**: Admin deve alterar role no painel de usuários.

---

## 📚 Documentação Adicional

- [INSTALL.md](INSTALL.md) - Guia completo de instalação passo-a-passo
- [SETUP_DO_ZERO.md](SETUP_DO_ZERO.md) - Análise técnica da arquitetura

---

## 🔄 Atualizações e Manutenção

```bash
# Atualizar código (sem tocar em dados)
git pull
docker compose up -d --build

# Backup de dados
docker compose exec postgres pg_dump -U dataplatform superset_db > backup_superset.sql
docker compose exec postgres pg_dump -U dataplatform airflow_db > backup_airflow.sql

# Restore de backup
cat backup_superset.sql | docker compose exec -T postgres psql -U dataplatform superset_db
```

---

## 📞 Suporte

Para problemas ou dúvidas, consulte:
1. Logs dos containers: `docker compose logs`
2. [INSTALL.md](INSTALL.md) para troubleshooting detalhado
3. Issues no GitHub: https://github.com/CamilloBorges/superset_airflow_env/issues

---

**Versão**: 2.0  
**Data**: 2026-06-06  
**Autor**: Plataforma de Dados Bomgado
