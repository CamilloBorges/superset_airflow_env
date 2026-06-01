#!/bin/bash
set -e

# Script para criar os bancos de dados necessários para Airflow e Superset

echo "Criando banco de dados para o Airflow..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE airflow_db;
    GRANT ALL PRIVILEGES ON DATABASE airflow_db TO $POSTGRES_USER;
EOSQL

echo "Criando banco de dados para o Superset..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE superset_db;
    GRANT ALL PRIVILEGES ON DATABASE superset_db TO $POSTGRES_USER;
EOSQL

echo "Bancos de dados criados com sucesso!"
