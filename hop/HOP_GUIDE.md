# Apache Hop - Guia de Uso

## 📘 Introdução

O Apache Hop (Hop Orchestration Platform) é o motor de ETL/ELT desta plataforma, executando transformações de dados e pipelines orquestrados pelo Airflow.

## 🏗️ Estrutura de Projetos Hop

```
hop/
├── config/               # Configurações do Hop
│   ├── hop-config.json   # Configuração principal
│   └── metadata/         # Metadados de conexões
│
├── projects/             # Seus projetos Hop
│   ├── exemplo_etl/
│   │   ├── metadata/
│   │   │   ├── database-connection/
│   │   │   ├── pipeline-run-configuration/
│   │   │   └── workflow-run-configuration/
│   │   ├── pipelines/    # Pipelines (.hpl)
│   │   │   ├── extract.hpl
│   │   │   ├── transform.hpl
│   │   │   └── load.hpl
│   │   └── workflows/    # Workflows (.hwf)
│   │       └── main_workflow.hwf
│   │
│   └── outro_projeto/
│
└── metadata/             # Cache e histórico de execução
```

## 🚀 Criando um Projeto Hop

### Opção 1: Usando o Hop GUI (recomendado para desenvolvimento)

1. Baixe o Apache Hop localmente: https://hop.apache.org/download/
2. Execute o Hop GUI: `hop-gui.bat` (Windows) ou `hop-gui.sh` (Linux/Mac)
3. Crie seu projeto e salve em `hop/projects/`
4. Os arquivos ficarão disponíveis automaticamente no container

### Opção 2: Via linha de comando no container

```bash
# Acessar o container
docker exec -it hop-server bash

# Criar novo projeto
cd /opt/hop
./hop-conf.sh --project-create \
  --project-name=meu_projeto \
  --project-home=/opt/hop/projects/meu_projeto \
  --project-config-file=/opt/hop/config

# Criar pipeline
./hop-conf.sh --project=meu_projeto \
  --pipeline-create \
  --pipeline-name=meu_pipeline \
  --pipeline-file=/opt/hop/projects/meu_projeto/pipelines/meu_pipeline.hpl
```

## 🔌 Configurando Conexões de Banco de Dados

### Via Hop GUI (mais fácil)

1. Abra o Hop GUI
2. Vá em: **Metadata → Database Connection → New**
3. Configure a conexão (ex: PostgreSQL, MySQL, etc.)
4. Salve em `hop/projects/seu_projeto/metadata/database-connection/`

### Via Arquivo JSON

Crie o arquivo: `hop/projects/seu_projeto/metadata/database-connection/postgres_conn.json`

```json
{
  "name": "postgres_data_warehouse",
  "description": "Conexão com Data Warehouse PostgreSQL",
  "pluginId": "PostgreSQL",
  "pluginName": "PostgreSQL",
  "databaseType": "PostgreSQL",
  "hostname": "postgres",
  "port": "5432",
  "databaseName": "data_warehouse",
  "username": "dataplatform",
  "password": "encrypted:...",
  "attributes": {}
}
```

## ▶️ Executando Pipelines do Hop

### 1. Execução Direta no Container

```bash
# Executar pipeline específico
docker exec hop-server /opt/hop/hop-run.sh \
  --file=/opt/hop/projects/meu_projeto/pipelines/extract.hpl \
  --runconfig=local \
  --level=Basic

# Executar workflow
docker exec hop-server /opt/hop/hop-run.sh \
  --file=/opt/hop/projects/meu_projeto/workflows/main.hwf \
  --runconfig=local \
  --level=Basic

# Com parâmetros
docker exec hop-server /opt/hop/hop-run.sh \
  --file=/opt/hop/projects/meu_projeto/pipelines/extract.hpl \
  --runconfig=production \
  --parameters=DATA_INICIO=2024-01-01,DATA_FIM=2024-12-31 \
  --level=Detailed
```

### 2. Via Airflow (Orquestração - Recomendado)

Crie uma DAG no Airflow (`airflow/dags/meu_pipeline.py`):

```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

with DAG(
    'hop_meu_pipeline',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False,
) as dag:

    executar_pipeline = BashOperator(
        task_id='hop_extract',
        bash_command="""
        docker exec hop-server /opt/hop/hop-run.sh \
          --file=/opt/hop/projects/meu_projeto/pipelines/extract.hpl \
          --runconfig=production \
          --parameters=EXECUTION_DATE={{ ds }} \
          --level=Basic
        """,
    )
```

## 🔧 Configurações de Execução

### Run Configurations

Crie configurações diferentes para ambientes:

**Local (desenvolvimento)**
- `hop/projects/meu_projeto/metadata/pipeline-run-configuration/local.json`

```json
{
  "name": "local",
  "description": "Configuração para desenvolvimento local",
  "engineRunConfiguration": {
    "enginePluginId": "Local",
    "enginePluginName": "Hop local pipeline engine"
  }
}
```

**Production (produção)**
- `hop/projects/meu_projeto/metadata/pipeline-run-configuration/production.json`

```json
{
  "name": "production",
  "description": "Configuração para ambiente de produção",
  "engineRunConfiguration": {
    "enginePluginId": "Local",
    "enginePluginName": "Hop local pipeline engine",
    "sampleRows": 100,
    "safeModeEnabled": true,
    "sortTransformsTopologically": true
  }
}
```

## 📊 Exemplo Prático Completo

### Pipeline de ETL: Extração de CSV para PostgreSQL

1. **Criar a estrutura do projeto:**

```bash
mkdir -p hop/projects/csv_to_postgres/{pipelines,metadata/database-connection}
```

2. **Criar conexão com PostgreSQL:**

`hop/projects/csv_to_postgres/metadata/database-connection/target_db.json`

3. **Desenvolver o pipeline no Hop GUI:**

   - **Transform 1:** CSV File Input → Lê arquivo CSV de `/shared/data/input/`
   - **Transform 2:** Select Values → Seleciona e renomeia campos
   - **Transform 3:** Data Validator → Valida tipos e valores
   - **Transform 4:** Table Output → Grava no PostgreSQL

4. **Salvar o pipeline:**
   - Arquivo: `hop/projects/csv_to_postgres/pipelines/csv_to_postgres.hpl`

5. **Criar DAG no Airflow para orquestrar:**

```python
# airflow/dags/csv_to_postgres_dag.py
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    'csv_to_postgres',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
) as dag:

    load_csv = BashOperator(
        task_id='hop_load_csv_to_postgres',
        bash_command="""
        docker exec hop-server /opt/hop/hop-run.sh \
          --file=/opt/hop/projects/csv_to_postgres/pipelines/csv_to_postgres.hpl \
          --runconfig=production
        """,
    )
```

## 🔍 Monitoramento e Logs

### Ver logs de execução

```bash
# Logs do container Hop
docker compose logs -f hop-server

# Logs dentro do container (caso configurado)
docker exec hop-server tail -f /opt/hop/logs/hop.log
```

### Métricas via API do Hop Server

```bash
# Status do servidor
curl http://localhost:8081/

# Listar configurações
curl -u "$HOP_SERVER_USER:$HOP_SERVER_PASS" http://localhost:8081/hop/listConfigurations
```

## 🌐 Volumes Compartilhados

Os seguintes diretórios são compartilhados entre Hop e Airflow:

- `/shared/data/` - Arquivos de dados temporários e intermediários
- `/hop/projects/` - Projetos Hop (leitura pelo Airflow)

Use esses volumes para:
- Armazenar arquivos CSV/Parquet intermediários
- Compartilhar resultados entre pipelines
- Transferir dados entre Hop e Airflow

## 📚 Recursos Adicionais

- **Documentação Oficial:** https://hop.apache.org/manual/latest/
- **Plugins Disponíveis:** https://hop.apache.org/manual/latest/plugins/plugins.html
- **Exemplos de Pipelines:** https://github.com/apache/hop/tree/master/integration-tests/transforms

## ⚠️ Boas Práticas

1. **Sempre use run configurations** diferentes para dev/prod
2. **Parametrize seus pipelines** para reutilização
3. **Valide dados** em cada etapa crítica
4. **Use workflows** para orquestrar múltiplos pipelines
5. **Teste localmente** antes de executar via Airflow
6. **Documente suas transformações** no próprio pipeline
7. **Use variáveis de ambiente** para credenciais sensíveis
8. **Monitore logs** regularmente

## 🆘 Troubleshooting

### Pipeline não encontrado

```bash
# Verificar se o arquivo existe
docker exec hop-server ls -la /opt/hop/projects/seu_projeto/pipelines/
```

### Erro de permissão

```bash
# Ajustar permissões (Linux/Mac)
chmod -R 755 hop/projects/
```

### Conexão com banco falha

- Verifique se o banco está na mesma rede Docker
- Use hostname do container, não `localhost`
- Confirme usuário/senha nas variáveis de ambiente

---

**Happy Data Engineering!** 🚀
