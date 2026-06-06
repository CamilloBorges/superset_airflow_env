#!/bin/bash
################################################################################
# Azure Key Vault - Script de Criação de Segredos
# 
# Este script cria todos os segredos necessários no Azure Key Vault.
# Execute apenas UMA VEZ após criar o Key Vault.
################################################################################

set -e

VAULT_NAME="bomgado-vault"
TENANT_ID="0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035"

echo "======================================================================"
echo " Azure Key Vault - Setup de Segredos"
echo " Vault: $VAULT_NAME"
echo "======================================================================"

# Verificar se Azure CLI está instalado
if ! command -v az &> /dev/null; then
    echo "❌ ERROR: Azure CLI não está instalado"
    echo "Instale: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Login no Azure
echo ""
echo "Fazendo login no Azure..."
az login --tenant $TENANT_ID

# Verificar se o Key Vault existe
echo ""
echo "Verificando Key Vault..."
if ! az keyvault show --name $VAULT_NAME &> /dev/null; then
    echo "❌ ERROR: Key Vault '$VAULT_NAME' não encontrado"
    echo "Crie o Key Vault primeiro no Azure Portal ou execute:"
    echo "  az keyvault create --name $VAULT_NAME --resource-group <RESOURCE_GROUP> --location brazilsouth"
    exit 1
fi

echo "✓ Key Vault encontrado"

# Função para criar/atualizar segredo
create_secret() {
    local name=$1
    local value=$2
    local description=$3
    
    echo "  Criando: $name ($description)"
    az keyvault secret set \
        --vault-name $VAULT_NAME \
        --name "$name" \
        --value "$value" \
        --output none
}

echo ""
echo "======================================================================"
echo " Criando Segredos"
echo "======================================================================"

# PostgreSQL
echo ""
echo "PostgreSQL:"
create_secret "postgres-user" "dataplatform" "PostgreSQL username"
create_secret "postgres-password" "Bomgado@233751" "PostgreSQL password"
create_secret "postgres-host" "postgres" "PostgreSQL hostname"
create_secret "postgres-port" "5432" "PostgreSQL port"
create_secret "postgres-airflow-db" "airflow_db" "Airflow database name"
create_secret "postgres-superset-db" "superset_db" "Superset database name"

# Redis
echo ""
echo "Redis:"
create_secret "redis-host" "redis" "Redis hostname"
create_secret "redis-port" "6379" "Redis port"
create_secret "redis-password" "Bomgado@233751" "Redis password"

# Airflow
echo ""
echo "Airflow:"
create_secret "airflow-fernet-key" "q7ItG0Si3Fyw3aqfk-X9vcq9h_twZoWNmJJ_pRIFYkk" "Airflow Fernet key"
create_secret "airflow-webserver-secret-key" "3Pz-SW0QLF8h9lR7jq8__6p9fMEwfIk_xfifkyoYRKs" "Airflow webserver secret"
create_secret "airflow-admin-username" "admin" "Airflow admin username"
create_secret "airflow-admin-password" "admin123" "Airflow admin password"
create_secret "airflow-admin-firstname" "Admin" "Airflow admin first name"
create_secret "airflow-admin-lastname" "User" "Airflow admin last name"
create_secret "airflow-admin-email" "admin@dataplatform.local" "Airflow admin email"

# Superset
echo ""
echo "Superset:"
# Gerar secret key se openssl disponível
if command -v openssl &> /dev/null; then
    SUPERSET_KEY=$(openssl rand -base64 42)
else
    SUPERSET_KEY="YOUR_SECRET_KEY_AT_LEAST_42_BYTES_LONG_PLEASE_GENERATE"
fi
create_secret "superset-secret-key" "$SUPERSET_KEY" "Superset secret key"
create_secret "superset-admin-username" "admin" "Superset admin username"
create_secret "superset-admin-password" "admin123" "Superset admin password"
create_secret "superset-admin-firstname" "Admin" "Superset admin first name"
create_secret "superset-admin-lastname" "User" "Superset admin last name"
create_secret "superset-admin-email" "admin@dataplatform.local" "Superset admin email"

# Azure Entra ID
echo ""
echo "Azure Entra ID (OAuth):"
create_secret "azure-tenant-id" "$TENANT_ID" "Azure Tenant ID"
create_secret "azure-superset-client-id" "d4ef29a3-49da-4ca1-a8a8-e8f786123224" "Superset App Registration Client ID"
create_secret "azure-superset-client-secret" "SEU_CLIENT_SECRET_AQUI" "Superset App Registration Client Secret (OBTENHA DO AZURE PORTAL)"
create_secret "azure-airflow-client-id" "d4ef29a3-49da-4ca1-a8a8-e8f786123224" "Airflow App Registration Client ID"
create_secret "azure-airflow-client-secret" "SEU_CLIENT_SECRET_AQUI" "Airflow App Registration Client Secret (OBTENHA DO AZURE PORTAL)"

echo ""
echo "======================================================================"
echo " ✓ Todos os segredos foram criados com sucesso!"
echo "======================================================================"
echo ""
echo "Próximos passos:"
echo ""
echo "1. Configurar acesso ao Key Vault:"
echo ""
echo "   OPÇÃO A - Managed Identity (Produção - VM Azure):"
echo "   ------------------------------------------------"
echo "   # Habilitar Managed Identity na VM"
echo "   az vm identity assign --name bomgado --resource-group <RESOURCE_GROUP>"
echo ""
echo "   # Obter Principal ID"
echo "   VM_PRINCIPAL=\$(az vm identity show --name bomgado --resource-group <RESOURCE_GROUP> --query principalId -o tsv)"
echo ""
echo "   # Conceder permissões"
echo "   az keyvault set-policy --name $VAULT_NAME --object-id \$VM_PRINCIPAL --secret-permissions get list"
echo ""
echo "   OPÇÃO B - Service Principal (Desenvolvimento Local):"
echo "   ---------------------------------------------------"
echo "   # Criar Service Principal"
echo "   az ad sp create-for-rbac --name bomgado-dataplatform-sp --role Reader"
echo ""
echo "   # Anotar appId, password, tenant"
echo "   # Conceder permissões"
echo "   az keyvault set-policy --name $VAULT_NAME --spn <appId> --secret-permissions get list"
echo ""
echo "   # Adicionar no .env:"
echo "   AZURE_CLIENT_ID=<appId>"
echo "   AZURE_CLIENT_SECRET=<password>"
echo "   AZURE_TENANT_ID=$TENANT_ID"
echo ""
echo "2. Testar carregamento de segredos:"
echo "   python3 shared/load_secrets.py"
echo ""
echo "3. Deploy:"
echo "   bash deploy-keyvault.sh"
echo ""
