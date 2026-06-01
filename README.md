# Plataforma de Dados - BI & Engenharia de Dados

Ambiente completo de Business Intelligence e Engenharia de Dados baseado em containers Docker, seguindo o princípio de **Infrastructure as Code (IaC)**.

> 🚀 **Início Rápido?** Consulte [QUICKSTART.md](QUICKSTART.md) para setup em 5 minutos  
> 🐧 **Ubuntu Server do Zero?** Consulte [UBUNTU_SETUP.md](UBUNTU_SETUP.md) para guia completo  
> 🌩️ **Usando Azure?** Consulte [AZURE_SETUP.md](AZURE_SETUP.md) para configurar NSG e portas  
> 🔒 **Configurar HTTPS?** Consulte [HTTPS_SETUP.md](HTTPS_SETUP.md) - Nginx já está configurado!  
> 🔐 **Quer SSO com Azure Entra ID?** Consulte [AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md) para configuração

## 🏗️ Arquitetura da Stack

Esta plataforma integra as seguintes ferramentas open-source:

- **Nginx** (Alpine) - Reverse proxy com HTTPS/SSL (porta 443, 8443, 8444)
- **Apache Airflow** (v2.8.0) - Orquestrador de workflows com CeleryExecutor
- **Apache Superset** (v3.0.0) - Plataforma de visualização e BI
- **Apache Hop** (v2.7.0) - Motor de ETL/ELT
- **PostgreSQL** (v15) - Banco de dados de metadados
- **Redis** (v7) - Message broker para Celery

### Fluxo de Acesso

```
Internet (HTTPS)
    ↓
Nginx Reverse Proxy (443, 8443, 8444)
    ↓
┌──────────────┬──────────────┬──────────────┐
│  Superset    │   Airflow    │     Hop      │
│   :8088      │   :8080      │   :8081      │
└──────────────┴──────────────┴──────────────┘
         ↓              ↓
    ┌────────┐     ┌─────┐
    │ PostgreSQL │   │ Redis │
    │   :5432   │   │ :6379 │
    └────────┘     └─────┘
```

## 📁 Estrutura do Repositório

```
superset_airflow_env/
├── .env.example                    # Template de variáveis de ambiente
├── .gitignore                      # Arquivos ignorados pelo Git
├── docker-compose.yml              # Definição completa da infraestrutura (13 serviços)
├── README.md                       # Esta documentação
│
├── nginx/                          # Nginx Reverse Proxy
│   └── nginx.conf                  # Configuração HTTPS
│
├── certs/                          # Certificados SSL (gerados automaticamente)
│   ├── cert.pem                    # Certificado SSL
│   └── key.pem                     # Chave privada
│
├── airflow/                        # Apache Airflow
│   ├── dags/                       # DAGs (pipelines do Airflow)
│   ├── logs/                       # Logs de execução
│   ├── plugins/                    # Plugins customizados
│   └── config/                     # Arquivos de configuração
│
├── superset/                       # Apache Superset
│   ├── config/                     # Configurações do Superset
│   └── data/                       # Dados e caches
│
├── hop/                            # Apache Hop
│   ├── config/                     # Configurações do Hop
│   ├── projects/                   # Projetos e pipelines Hop
│   └── metadata/                   # Metadados e histórico
│
├── postgres/                       # PostgreSQL
│   └── init-scripts/               # Scripts de inicialização do banco
│
└── shared/                         # Arquivos compartilhados
    └── data/                       # Dados compartilhados entre serviços
```

## 🚀 Guia de Inicialização

### Pré-requisitos

- **Docker** (versão 20.10 ou superior)
- **Docker Compose** (versão 2.0 ou superior)
- Pelo menos **8GB de RAM** disponível para os containers
- **10GB de espaço em disco** livre
- **OpenSSL** (para geração de certificados SSL)

> 📘 **Instalando em Ubuntu Server do Zero?**  
> Consulte o guia completo: [UBUNTU_SETUP.md](UBUNTU_SETUP.md) - inclui instalação do Docker, configuração de permissões e setup completo passo a passo.

### Passo 1: Clonar o Repositório

```bash
git clone <url-do-repositorio>
cd superset_airflow_env
```

### Passo 2: Configurar Variáveis de Ambiente

Copie o arquivo de exemplo e edite com suas configurações:

```bash
cp .env.example .env
```

⚠️ **IMPORTANTE**: Edite o arquivo `.env` e configure:

1. **Domínio/IP Público** (OBRIGATÓRIO para HTTPS):
   - `PUBLIC_DOMAIN` - Seu domínio ou IP público (ex: `172.174.210.23` ou `dados.suaempresa.com`)

2. **Senhas e Secrets** (OBRIGATÓRIO):
   - `POSTGRES_PASSWORD` - Senha do PostgreSQL
   - `REDIS_PASSWORD` - Senha do Redis
   - `AIRFLOW__CORE__FERNET_KEY` - Chave Fernet do Airflow
   - `AIRFLOW__WEBSERVER__SECRET_KEY` - Secret key do webserver
   - `SUPERSET_SECRET_KEY` - Secret key do Superset (mínimo 42 caracteres)

3. **Gerar Fernet Key para o Airflow**:

```bash
# Python
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Ou use Docker:

```bash
docker run --rm python:3.11-slim sh -c "pip install cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
```

### Passo 3: Gerar Certificados SSL

**Nginx requer HTTPS.** Escolha uma opção:

**Opção A: Certificado Auto-assinado (Desenvolvimento/Teste)**

```bash
./generate-ssl-cert.sh
```

**Opção B: Let's Encrypt (Produção com Domínio)**

```bash
# Configure PUBLIC_DOMAIN no .env primeiro
./generate-letsencrypt-cert.sh
```

> 📘 **Detalhes sobre HTTPS:** [HTTPS_SETUP.md](HTTPS_SETUP.md)

### Passo 4: Ajustar AIRFLOW_UID (Linux/Mac)

```bash
echo "AIRFLOW_UID=$(id -u)" >> .env
```

No Windows, mantenha o valor padrão `50000`.

### Passo 3: Ajustar Permissões (Linux/Mac)

**IMPORTANTE**: No Linux/Mac, é necessário ajustar permissões antes de iniciar:

```bash
# Dar permissão de execução aos scripts
chmod +x quick-start.sh
chmod +x postgres/init-scripts/*.sh

# Criar diretórios necessários
mkdir -p airflow/logs airflow/dags airflow/plugins

# Ajustar permissões do Airflow (UID 50000)
sudo chown -R 50000:0 airflow/
chmod -R 755 airflow/
chmod -R 777 airflow/logs
```

**No Windows**, não é necessário ajustar permissões.

### Passo 4: Criar Diretórios com Permissões (Linux/Mac)

```bash
mkdir -p airflow/logs airflow/dags airflow/plugins
chmod -R 777 airflow/logs
```

No Windows, não é necessário.

### Passo 5: Inicializar o Ambiente

Execute o comando para subir todos os serviços:

**Linux/Mac:**
```bash
# Dar permissão de execução ao script (primeira vez)
chmod +x quick-start.sh

# Executar script de inicialização
./quick-start.sh
```

**Windows PowerShell:**
```powershell
.\quick-start.ps1
```

**Ou manualmente (qualquer plataforma):**
```bash
docker compose up -d
```

Este comando irá:
1. Baixar todas as imagens Docker necessárias
2. Criar os bancos de dados no PostgreSQL
3. Inicializar o banco de metadados do Airflow
4. Criar usuário admin do Airflow
5. Inicializar o banco de metadados do Superset
6. Criar usuário admin do Superset
7. Subir todos os serviços

⏱️ **Tempo estimado**: 5-10 minutos na primeira execução.

### Passo 6: Verificar o Status dos Serviços

```bash
docker compose ps
```

Todos os serviços devem estar com status `healthy` ou `running`.

### Passo 7: Acessar as Interfaces Web

Após a inicialização completa, acesse:

| Serviço | URL | Usuário Padrão | Senha Padrão |
|---------|-----|----------------|--------------|
| **Apache Superset** | https://SEU_DOMINIO:443 | admin | admin123 |
| **Apache Airflow** | https://SEU_DOMINIO:8443 | admin | admin123 |
| **Apache Hop** | https://SEU_DOMINIO:8444 | cluster | cluster |

> 💡 Substitua `SEU_DOMINIO` pelo valor de `PUBLIC_DOMAIN` configurado no .env  
> 📝 **Exemplos:**  
> - Com IP: `https://172.174.210.23`, `https://172.174.210.23:8443`  
> - Com domínio: `https://dados.suaempresa.com`, `https://dados.suaempresa.com:8443`

⚠️ **IMPORTANTE**: 
- Certificados auto-assinados causarão aviso de segurança (clique "Avançado" → "Prosseguir")
- Altere as senhas padrão após o primeiro login!

---

## 📋 Recursos Adicionais

- **[QUICKSTART.md](QUICKSTART.md)** - Início rápido em 5 minutos
- **[CHECKLIST.md](CHECKLIST.md)** - Checklist completo de instalação e verificação
- **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** - Guia completo para Ubuntu Server do zero
- **[AZURE_SETUP.md](AZURE_SETUP.md)** - Configuração de NSG e rede no Azure
- **[HTTPS_SETUP.md](HTTPS_SETUP.md)** - Configuração SSL/TLS (Nginx)
- **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** - Configurar SSO com Azure Entra ID
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solução de problemas comuns
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Estrutura detalhada do projeto
- **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** - Guia de uso do Apache Hop

---

## 🔧 Operações Comuns

### Visualizar Logs

```bash
# Todos os serviços
docker compose logs -f

# Serviço específico
docker compose logs -f airflow-webserver
docker compose logs -f superset
docker compose logs -f hop-server
```

### Parar o Ambiente

```bash
docker compose stop
```

### Iniciar o Ambiente (após parar)

```bash
docker compose start
```

### Reiniciar um Serviço Específico

```bash
docker compose restart airflow-scheduler
docker compose restart superset
```

### Destruir o Ambiente Completamente

⚠️ **ATENÇÃO**: Isso removerá todos os containers, volumes e dados!

```bash
docker compose down -v
```

### Atualizar Imagens

```bash
docker compose pull
docker compose up -d
```

## 🔌 Integração Airflow + Hop

Para executar pipelines do Apache Hop a partir de DAGs do Airflow:

### 1. Criar uma DAG de Exemplo

Crie o arquivo `airflow/dags/hop_example_dag.py`:

```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'hop_pipeline_example',
    default_args=default_args,
    description='Exemplo de execução de pipeline Hop via Airflow',
    schedule_interval='@daily',
    catchup=False,
    tags=['hop', 'etl'],
) as dag:

    run_hop_pipeline = BashOperator(
        task_id='execute_hop_pipeline',
        bash_command='''
        docker exec hop-server /opt/hop/hop-run.sh \
          --file=/opt/hop/projects/exemplo/pipeline.hpl \
          --runconfig=local \
          --level=Basic
        ''',
    )

    run_hop_pipeline
```

### 2. Acessar Volumes Compartilhados

Os pipelines do Hop devem ser salvos em `hop/projects/` e estarão acessíveis tanto no container do Hop quanto no Airflow através de volumes compartilhados.

## 🔐 Segurança

### Conexões com Bancos de Dados no Airflow

Para adicionar conexões no Airflow:

1. Acesse o Airflow UI → Admin → Connections
2. Adicione suas conexões de banco de dados, APIs, etc.
3. Utilize as variáveis de ambiente quando possível

### Conexões no Superset

Para conectar o Superset a fontes de dados:

1. Acesse Superset UI → Settings → Database Connections
2. Adicione conexões usando SQLAlchemy URIs

Exemplo para PostgreSQL local:
```
postgresql://usuario:senha@postgres:5432/nome_banco
```

## 📊 Configuração do Executor

O ambiente está configurado para usar **CeleryExecutor** por padrão, permitindo execução distribuída de tarefas.

Para usar **LocalExecutor** (mais simples, sem workers):

1. Edite o arquivo `.env`:
```bash
AIRFLOW_EXECUTOR=LocalExecutor
```

2. Comente ou remova o serviço `airflow-worker` no `docker-compose.yml`

3. Reinicie o ambiente:
```bash
docker compose down
docker compose up -d
```

## 🐛 Troubleshooting

### Problema: Serviços não inicializam

**Solução**: Verifique os logs:
```bash
docker compose logs postgres
docker compose logs redis
```

### Problema: "Permission denied" no Airflow (Linux/Mac)

**Solução**: Ajuste as permissões:
```bash
sudo chown -R $(id -u):0 airflow/
chmod -R 755 airflow/
chmod -R 777 airflow/logs
```

### Problema: Porta já em uso

**Solução**: Altere as portas no arquivo `.env`:
```bash
AIRFLOW_EXTERNAL_PORT=8081
SUPERSET_EXTERNAL_PORT=8089
```

### Problema: Falta de memória

**Solução**: Aumente a memória disponível para o Docker (configurações do Docker Desktop) para pelo menos 8GB.

### Resetar Ambiente Completamente

```bash
docker compose down -v
rm -rf airflow/logs/*
rm -rf superset/data/*
docker compose up -d
```

## 📚 Documentação Oficial

- [Apache Airflow](https://airflow.apache.org/docs/)
- [Apache Superset](https://superset.apache.org/docs/intro)
- [Apache Hop](https://hop.apache.org/manual/latest/)
- [Docker Compose](https://docs.docker.com/compose/)

## 🤝 Contribuindo

Este projeto segue o princípio de Infrastructure as Code. Para contribuir:

1. Crie um branch para suas mudanças
2. Teste localmente com `docker compose up`
3. Commit suas mudanças com mensagens descritivas
4. Abra um Pull Request

## 📝 Licença

Este projeto utiliza ferramentas open-source. Consulte as licenças individuais:
- Apache Airflow: Apache License 2.0
- Apache Superset: Apache License 2.0
- Apache Hop: Apache License 2.0

---

**Desenvolvido para Engenharia de Dados e Business Intelligence** 🚀
