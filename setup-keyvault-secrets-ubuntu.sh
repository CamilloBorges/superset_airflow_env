#!/bin/bash
################################################################################
# Azure Key Vault - Script de Criação de Segredos (Bash para Ubuntu)
# 
# Execute na VM Azure: bash setup-keyvault-secrets-ubuntu.sh
################################################################################

set -e

VAULT_NAME="bomgado-vault"
TENANT_ID="e97132bc-f926-4fba-9f6e-0379c8f25b23"  # bomgado.com.br (infraestrutura)

echo "======================================================================"
echo " Azure Key Vault - Setup de Segredos"
echo " Vault: $VAULT_NAME"
echo "======================================================================"

# Verificar se Azure CLI está instalado
if ! command -v az &> /dev/null; then
    echo "❌ ERROR: Azure CLI não está instalado"
    echo "Instalando Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

echo "✓ Azure CLI instalado: $(az version --query '"azure-cli"' -o tsv)"

# Login no Azure
echo ""
echo "Fazendo login no Azure (Tenant: $TENANT_ID)..."
az login --tenant $TENANT_ID --output none || {
    echo "❌ Falha no login do Azure"
    exit 1
}

echo "✓ Login realizado com sucesso"

# Verificar acesso ao Key Vault
echo ""
echo "Verificando acesso ao Key Vault..."
if ! az keyvault show --name $VAULT_NAME --output none 2>/dev/null; then
    echo "❌ Não foi possível acessar o Key Vault: $VAULT_NAME"
    echo "Verifique se:"
    echo "  1. O Key Vault existe"
    echo "  2. Você tem permissões de Secret Officer"
    exit 1
fi

echo "✓ Key Vault encontrado: $VAULT_NAME"

echo ""
echo "======================================================================"
echo " Criando Segredos no Key Vault"
echo "======================================================================"

# Função para criar segredo
create_secret() {
    local name="$1"
    local value="$2"
    local description="$3"
    
    echo ""
    echo "[$name]"
    echo "  Descrição: $description"
    echo -n "  Criando... "
    
    if az keyvault secret set \
        --vault-name "$VAULT_NAME" \
        --name "$name" \
        --value "$value" \
        --output none 2>/dev/null; then
        echo "✓"
    else
        echo "✗ FALHA"
        return 1
    fi
}

# ============================================================================
# PostgreSQL Secrets
# ============================================================================
echo ""
echo "--- PostgreSQL Database ---"

create_secret "postgres-host" "postgres" "PostgreSQL hostname"
create_secret "postgres-port" "5432" "PostgreSQL port"
create_secret "postgres-user" "dataplatform" "PostgreSQL username"
create_secret "postgres-password" "Bomgado@233751" "PostgreSQL password"
create_secret "postgres-airflow-db" "airflow_db" "Airflow database name"
create_secret "postgres-superset-db" "superset_db" "Superset database name"

# ============================================================================
# Redis Secrets
# ============================================================================
echo ""
echo "--- Redis Cache ---"

create_secret "redis-host" "redis" "Redis hostname"
create_secret "redis-port" "6379" "Redis port"
create_secret "redis-password" "Bomgado@233751" "Redis password"

# ============================================================================
# Airflow Secrets
# ============================================================================
echo ""
echo "--- Apache Airflow ---"

create_secret "airflow-fernet-key" "q7ItG0Si3Fyw3aqfk-X9vcq9h_twZoWNmJJ_pRIFYkk" "Airflow Fernet encryption key"
create_secret "airflow-webserver-secret" "3Pz-SW0QLF8h9lR7jq8__6p9fMEwfIk_xfifkyoYRKs" "Airflow webserver secret key"
create_secret "airflow-admin-username" "admin" "Airflow admin username"
create_secret "airflow-admin-password" "admin123" "Airflow admin password"
create_secret "airflow-admin-firstname" "Admin" "Airflow admin first name"
create_secret "airflow-admin-lastname" "User" "Airflow admin last name"
create_secret "airflow-admin-email" "admin@bomgado.com.br" "Airflow admin email"

# ============================================================================
# Superset Secrets
# ============================================================================
echo ""
echo "--- Apache Superset ---"

create_secret "superset-secret-key" "YOUR_OWN_RANDOM_GENERATED_SECRET_KEY_CHANGE_THIS_IMMEDIATELY_$(date +%s)" "Superset Flask secret key"
create_secret "superset-admin-username" "admin" "Superset admin username"
create_secret "superset-admin-password" "admin123" "Superset admin password"
create_secret "superset-admin-firstname" "Admin" "Superset admin first name"
create_secret "superset-admin-lastname" "User" "Superset admin last name"
create_secret "superset-admin-email" "admin@bomgado.com.br" "Superset admin email"

# ============================================================================
# Azure Entra ID (OAuth) Secrets
# ============================================================================
echo ""
echo "--- Azure Entra ID OAuth ---"

create_secret "azure-tenant-id" "0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035" "Azure Entra ID Tenant ID"
create_secret "azure-client-id-superset" "d4ef29a3-49da-4ca1-a8a8-e8f786123224" "Azure App Registration Client ID (Superset)"
create_secret "azure-client-id-airflow" "d4ef29a3-49da-4ca1-a8a8-e8f786123224" "Azure App Registration Client ID (Airflow)"
create_secret "azure-client-secret" "SEU_CLIENT_SECRET_AQUI" "Azure App Registration Client Secret (OBTENHA DO AZURE PORTAL)"
create_secret "public-domain" "bi.bomgado.com.br" "Public domain for OAuth callbacks"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "======================================================================"
echo " Resumo"
echo "======================================================================"
echo "  ✓ 25 segredos criados com sucesso no Key Vault: $VAULT_NAME"
echo ""
echo "Próximos passos:"
echo "  1. Configure Managed Identity: bash configure-managed-identity.sh"
echo "  2. Teste: python3 shared/check_vault_health.py"
echo "  3. Deploy: bash deploy-keyvault.sh"
echo ""
echo "======================================================================"
