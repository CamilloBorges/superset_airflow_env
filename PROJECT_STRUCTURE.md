# 📂 Estrutura Completa do Projeto

```
superset_airflow_env/
│
├── 📄 .env.example                     # Template de variáveis de ambiente
├── 📄 .env                             # Variáveis de ambiente (NÃO VERSIONAR)
├── 📄 .gitignore                       # Arquivos ignorados pelo Git
├── 📄 docker-compose.yml               # Orquestração de containers
├── 📄 README.md                        # Documentação principal
├── 📄 UBUNTU_SETUP.md                  # Setup completo Ubuntu Server do zero
├── 📄 CHECKLIST.md                     # Checklist de instalação
├── 📄 TROUBLESHOOTING.md               # Guia de solução de problemas
├── 📄 PROJECT_STRUCTURE.md             # Esta documentação
├── 📄 Makefile                         # Comandos auxiliares (Linux/Mac)
├── 📄 quick-start.sh                   # Script de inicialização (Linux/Mac)
├── 📄 quick-start.ps1                  # Script de inicialização (Windows)
├── 📄 generate_secrets.py              # Gerador de chaves de segurança
│
├── 📁 airflow/                         # Apache Airflow
│   ├── 📁 dags/                        # DAGs (pipelines Airflow)
│   │   ├── 📄 hop_etl_pipeline_example.py    # DAG de exemplo com Hop
│   │   └── 📄 [suas_outras_dags.py]
│   ├── 📁 logs/                        # Logs de execução (auto-gerado)
│   ├── 📁 plugins/                     # Plugins customizados
│   └── 📁 config/                      # Configurações adicionais
│
├── 📁 superset/                        # Apache Superset
│   ├── 📁 config/                      # Configurações
│   │   └── 📄 superset_config.py       # Configuração customizada
│   └── 📁 data/                        # Dados e caches (auto-gerado)
│
├── 📁 hop/                             # Apache Hop
│   ├── 📄 HOP_GUIDE.md                 # Guia de uso do Hop
│   ├── 📁 config/                      # Configurações do Hop
│   │   └── 📄 hop-config.json
│   ├── 📁 projects/                    # Projetos ETL
│   │   └── 📁 exemplo_etl/
│   │       ├── 📁 metadata/
│   │       │   ├── 📁 database-connection/
│   │       │   ├── 📁 pipeline-run-configuration/
│   │       │   └── 📁 workflow-run-configuration/
│   │       ├── 📁 pipelines/           # Pipelines (.hpl)
│   │       │   ├── 📄 01_extract.hpl
│   │       │   ├── 📄 02_transform.hpl
│   │       │   └── 📄 03_load.hpl
│   │       └── 📁 workflows/           # Workflows (.hwf)
│   │           └── 📄 main_workflow.hwf
│   └── 📁 metadata/                    # Cache e histórico (auto-gerado)
│
├── 📁 postgres/                        # PostgreSQL
│   └── 📁 init-scripts/                # Scripts de inicialização do DB
│       └── 📄 01-init-databases.sh     # Cria bancos airflow_db e superset_db
│
└── 📁 shared/                          # Arquivos compartilhados
    └── 📁 data/                        # Dados temporários entre serviços
        ├── 📁 input/                   # Arquivos de entrada
        ├── 📁 output/                  # Arquivos de saída
        └── 📁 temp/                    # Temporários
```

---

## 🎯 Arquivos Principais

### 🔧 Configuração

| Arquivo | Descrição | Versionar? |
|---------|-----------|------------|
| `.env.example` | Template de variáveis de ambiente | ✅ Sim |
| `.env` | Variáveis reais (senhas, secrets) | ❌ NÃO |
| `docker-compose.yml` | Definição da infraestrutura | ✅ Sim |
| `.gitignore` | Arquivos ignorados pelo Git | ✅ Sim |

### 📚 Documentação

| Arquivo | Descrição |
|---------|-----------|
| `README.md` | Guia completo do projeto |
| `UBUNTU_SETUP.md` | Setup completo para Ubuntu Server do zero |
| `CHECKLIST.md` | Checklist de instalação e verificação |
| `TROUBLESHOOTING.md` | Soluções para problemas comuns |
| `PROJECT_STRUCTURE.md` | Estrutura detalhada do projeto |
| `hop/HOP_GUIDE.md` | Guia específico do Apache Hop |

### 🚀 Scripts de Automação

| Arquivo | Descrição | Plataforma |
|---------|-----------|------------|
| `quick-start.sh` | Inicialização rápida | Linux/Mac |
| `quick-start.ps1` | Inicialização rápida | Windows |
| `generate_secrets.py` | Gera chaves de segurança | Todas |
| `Makefile` | Comandos úteis | Linux/Mac |

### 📊 Código de Exemplo

| Arquivo | Descrição |
|---------|-----------|
| `airflow/dags/hop_etl_pipeline_example.py` | DAG de exemplo |
| `superset/config/superset_config.py` | Config customizada Superset |

---

## 🔐 Arquivos Sensíveis (NÃO versionar)

Estes arquivos contêm dados sensíveis e **NÃO devem** ser commitados no Git:

```
❌ .env                          # Senhas e secrets reais
❌ airflow/logs/*                # Logs podem conter dados sensíveis
❌ superset/data/*               # Dados de cache
❌ hop/metadata/*                # Histórico de execução
❌ shared/data/*                 # Dados temporários
❌ *.db, *.sqlite                # Bancos de dados locais
❌ *.pem, *.key, *.crt           # Certificados e chaves
```

---

## ✅ Arquivos para Versionar

Estes arquivos **DEVEM** ser commitados no Git:

```
✅ .env.example                  # Template (sem senhas reais)
✅ .gitignore                    # Regras do Git
✅ docker-compose.yml            # Infraestrutura
✅ README.md                     # Documentação
✅ TROUBLESHOOTING.md            # Guias
✅ Makefile                      # Scripts
✅ quick-start.*                 # Scripts de inicialização
✅ generate_secrets.py           # Utilitários
✅ airflow/dags/*.py             # DAGs
✅ airflow/plugins/*.py          # Plugins customizados
✅ superset/config/*.py          # Configurações (sem senhas)
✅ hop/projects/**/*.hpl         # Pipelines Hop
✅ hop/projects/**/*.hwf         # Workflows Hop
✅ hop/projects/**/metadata/**/*.json  # Metadados de projeto
✅ postgres/init-scripts/*.sh    # Scripts de inicialização DB
```

---

## 🏗️ Containers Docker

| Container | Imagem | Porta | Descrição |
|-----------|--------|-------|-----------|
| `postgres` | postgres:15-alpine | 5432 | Banco de metadados |
| `redis` | redis:7-alpine | 6379 | Message broker |
| `airflow-init` | apache/airflow:2.8.0 | - | Inicialização do Airflow |
| `airflow-webserver` | apache/airflow:2.8.0 | 8080 | Interface web Airflow |
| `airflow-scheduler` | apache/airflow:2.8.0 | - | Agendador Airflow |
| `airflow-worker` | apache/airflow:2.8.0 | - | Worker Celery (opcional) |
| `airflow-triggerer` | apache/airflow:2.8.0 | - | Triggerer Airflow |
| `superset-init` | apache/superset:3.0.0 | - | Inicialização Superset |
| `superset` | apache/superset:3.0.0 | 8088 | Interface web Superset |
| `superset-worker` | apache/superset:3.0.0 | - | Worker Celery Superset |
| `superset-beat` | apache/superset:3.0.0 | - | Beat Celery Superset |
| `hop-server` | apache/hop:2.7.0 | 8081 | Servidor Hop |

---

## 📦 Volumes Docker

| Volume | Descrição | Persistência |
|--------|-----------|--------------|
| `postgres-data` | Dados do PostgreSQL | ✅ Persistente |
| `./airflow/dags` | DAGs do Airflow | 📁 Bind mount |
| `./airflow/logs` | Logs do Airflow | 📁 Bind mount |
| `./airflow/plugins` | Plugins do Airflow | 📁 Bind mount |
| `./superset/config` | Config do Superset | 📁 Bind mount |
| `./superset/data` | Dados do Superset | 📁 Bind mount |
| `./hop/projects` | Projetos Hop | 📁 Bind mount |
| `./hop/config` | Config do Hop | 📁 Bind mount |
| `./shared` | Dados compartilhados | 📁 Bind mount |

---

## 🌐 Rede Docker

- **Nome:** `data-platform-network`
- **Driver:** bridge
- **Função:** Permite comunicação entre todos os containers

---

## 🔑 Variáveis de Ambiente Principais

### PostgreSQL
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_AIRFLOW_DB`
- `POSTGRES_SUPERSET_DB`

### Redis
- `REDIS_PASSWORD`

### Airflow
- `AIRFLOW_EXECUTOR` (LocalExecutor ou CeleryExecutor)
- `AIRFLOW__CORE__FERNET_KEY`
- `AIRFLOW__WEBSERVER__SECRET_KEY`
- `AIRFLOW_ADMIN_USERNAME`
- `AIRFLOW_ADMIN_PASSWORD`

### Superset
- `SUPERSET_SECRET_KEY`
- `SUPERSET_ADMIN_USERNAME`
- `SUPERSET_ADMIN_PASSWORD`

### Apache Hop
- `HOP_SERVER_USER`
- `HOP_SERVER_PASS`

---

## 📈 Fluxo de Dados

```
┌─────────────────┐
│   Fontes de     │
│     Dados       │
│  (CSV, APIs,    │
│   Bancos, etc)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Apache Hop    │◄─────── Orquestrado por ────────┐
│  (Motor ETL)    │                                  │
│   Transforma    │                                  │
│   e processa    │                                  │
└────────┬────────┘                                  │
         │                                           │
         ▼                                           │
┌─────────────────┐                         ┌───────┴────────┐
│  Data Warehouse │                         │ Apache Airflow │
│   PostgreSQL    │                         │  (Orquestrador)│
│     MySQL       │                         │   Agenda e     │
│   Data Lake     │                         │   monitora     │
└────────┬────────┘                         └────────────────┘
         │
         ▼
┌─────────────────┐
│ Apache Superset │
│  (Visualização) │
│   Dashboards    │
│   Relatórios    │
└─────────────────┘
```

---

## 🎓 Próximos Passos

### Para Ubuntu Server do Zero:
1. ✅ Consultar **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** para instalação completa
2. ✅ Instalar Docker e Docker Compose
3. ✅ Clonar/criar repositório Git
4. ✅ Seguir passos do guia Ubuntu

### Para Ambiente com Docker já instalado:
1. ✅ Clonar/criar repositório Git
2. ✅ Copiar `.env.example` para `.env`
3. ✅ Gerar chaves de segurança com `generate_secrets.py` ou Docker
4. ✅ Editar `.env` com as chaves geradas
5. ✅ Ajustar permissões (Linux/Mac): `chmod +x quick-start.sh`
6. ✅ Executar `./quick-start.sh` ou `docker compose up -d`
7. ✅ Verificar com **[CHECKLIST.md](CHECKLIST.md)**
8. ✅ Acessar Airflow, Superset e Hop
9. ✅ Criar seus primeiros pipelines Hop
10. ✅ Criar DAGs no Airflow para orquestrar
11. ✅ Criar dashboards no Superset

---

**Ambiente completo de Engenharia de Dados pronto para uso!** 🚀
