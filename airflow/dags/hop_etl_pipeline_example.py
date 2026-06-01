"""
DAG de Exemplo: Orquestração de Pipeline Apache Hop via Airflow
=================================================================

Este exemplo demonstra como executar pipelines do Apache Hop
a partir de DAGs do Airflow usando BashOperator ou DockerOperator.

Autor: Data Platform Team
Data: 2024
"""

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from datetime import datetime, timedelta
import logging

# Configurações padrão da DAG
default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email': ['data-team@company.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(hours=2),
}

# Definição da DAG
with DAG(
    dag_id='hop_etl_pipeline_example',
    default_args=default_args,
    description='Pipeline ETL completo usando Apache Hop orquestrado pelo Airflow',
    schedule_interval='0 2 * * *',  # Executa diariamente às 2h da manhã
    catchup=False,
    max_active_runs=1,
    tags=['etl', 'hop', 'data-pipeline', 'production'],
) as dag:

    # Task 1: Início do pipeline
    start = EmptyOperator(
        task_id='start_pipeline',
    )

    # Task 2: Validação de pré-requisitos
    def check_prerequisites(**context):
        """Valida se os arquivos de entrada existem"""
        import os
        
        required_files = [
            '/shared/data/input/source_data.csv',
        ]
        
        missing_files = [f for f in required_files if not os.path.exists(f)]
        
        if missing_files:
            raise FileNotFoundError(f"Arquivos não encontrados: {missing_files}")
        
        logging.info("✓ Todos os pré-requisitos validados com sucesso")
        return True

    validate_prerequisites = PythonOperator(
        task_id='validate_prerequisites',
        python_callable=check_prerequisites,
    )

    # Task 3: Executar pipeline de extração do Hop
    extract_data = BashOperator(
        task_id='hop_extract_data',
        bash_command="""
        docker exec hop-server /opt/hop/hop-run.sh \
          --file=/opt/hop/projects/etl_project/pipelines/01_extract.hpl \
          --runconfig=production \
          --parameters=EXECUTION_DATE={{ ds }} \
          --level=Basic
        """,
    )

    # Task 4: Executar pipeline de transformação do Hop
    transform_data = BashOperator(
        task_id='hop_transform_data',
        bash_command="""
        docker exec hop-server /opt/hop/hop-run.sh \
          --file=/opt/hop/projects/etl_project/pipelines/02_transform.hpl \
          --runconfig=production \
          --parameters=EXECUTION_DATE={{ ds }} \
          --level=Basic
        """,
    )

    # Task 5: Executar pipeline de carga do Hop
    load_data = BashOperator(
        task_id='hop_load_data',
        bash_command="""
        docker exec hop-server /opt/hop/hop-run.sh \
          --file=/opt/hop/projects/etl_project/pipelines/03_load.hpl \
          --runconfig=production \
          --parameters=EXECUTION_DATE={{ ds }} \
          --level=Basic
        """,
    )

    # Task 6: Validação dos dados carregados
    def validate_data_quality(**context):
        """Valida a qualidade dos dados após a carga"""
        import pandas as pd
        
        # Exemplo de validação
        # df = pd.read_csv('/shared/data/output/processed_data.csv')
        
        # if df.empty:
        #     raise ValueError("DataFrame vazio - falha na pipeline")
        
        # if df.isnull().sum().sum() > 0:
        #     logging.warning("⚠ Dados nulos encontrados!")
        
        logging.info("✓ Validação de qualidade concluída")
        return True

    validate_quality = PythonOperator(
        task_id='validate_data_quality',
        python_callable=validate_data_quality,
    )

    # Task 7: Atualizar cache do Superset (opcional)
    refresh_superset_cache = BashOperator(
        task_id='refresh_superset_cache',
        bash_command="""
        echo "Atualizando cache do Superset..."
        # Exemplo: docker exec superset superset cache-warmup
        """,
    )

    # Task 8: Finalização
    end = EmptyOperator(
        task_id='pipeline_completed',
    )

    # Definir dependências (ordem de execução)
    start >> validate_prerequisites >> extract_data >> transform_data >> load_data
    load_data >> validate_quality >> refresh_superset_cache >> end


# Documentação adicional
dag.doc_md = """
# Pipeline ETL - Apache Hop via Airflow

## Descrição
Este pipeline orquestra a execução de transformações ETL usando Apache Hop,
com validações e monitoramento via Airflow.

## Estrutura do Hop
```
hop/projects/etl_project/
├── pipelines/
│   ├── 01_extract.hpl
│   ├── 02_transform.hpl
│   └── 03_load.hpl
└── metadata/
```

## Parâmetros
- `EXECUTION_DATE`: Data de execução no formato YYYY-MM-DD

## Monitoramento
- Logs disponíveis em: `airflow/logs/`
- Métricas do Hop: http://localhost:8081

## Contato
Data Engineering Team
"""
