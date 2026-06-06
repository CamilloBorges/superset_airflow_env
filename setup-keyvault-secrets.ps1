################################################################################
# Azure Key Vault - Script de Criação de Segredos (PowerShell)
# 
# Este script cria todos os segredos necessários no Azure Key Vault.
# Execute apenas UMA VEZ após criar o Key Vault.
################################################################################

$ErrorActionPreference = "Stop"

$VAULT_NAME = "bomgado-vault"
$TENANT_ID = "e97132bc-f926-4fba-9f6e-0379c8f25b23"  # bomgado.com.br (infraestrutura)

Write-Host "======================================================================"
Write-Host " Azure Key Vault - Setup de Segredos"
Write-Host " Vault: $VAULT_NAME"
Write-Host "======================================================================"

# Verificar se Azure CLI está instalado
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "`n✓ Azure CLI instalado: $($azVersion.'azure-cli')"
} catch {
    Write-Host "`n❌ ERROR: Azure CLI não está instalado"
    Write-Host "Instale: https://aka.ms/installazurecliwindows"
    Write-Host "Ou execute: winget install Microsoft.AzureCLI"
    exit 1
}

# Login no Azure
Write-Host "`nFazendo login no Azure (Tenant: $TENANT_ID)..."
Write-Host "Uma janela do navegador será aberta..."
az login --tenant $TENANT_ID --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Falha no login do Azure"
    exit 1
}

Write-Host "✓ Login realizado com sucesso"

# Verificar acesso ao Key Vault
Write-Host "`nVerificando acesso ao Key Vault..."
try {
    az keyvault show --name $VAULT_NAME --output none
    Write-Host "✓ Key Vault encontrado: $VAULT_NAME"
} catch {
    Write-Host "❌ Não foi possível acessar o Key Vault: $VAULT_NAME"
    Write-Host "Verifique se:"
    Write-Host "  1. O Key Vault existe"
    Write-Host "  2. Você tem permissões de Secret Officer"
    exit 1
}

Write-Host "`n======================================================================"
Write-Host " Criando Segredos no Key Vault"
Write-Host "======================================================================"

# Função para criar segredo
function Set-KeyVaultSecret {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Description
    )
    
    Write-Host "`n[$Name]"
    Write-Host "  Descrição: $Description"
    Write-Host "  Criando..."
    
    az keyvault secret set `
        --vault-name $VAULT_NAME `
        --name $Name `
        --value $Value `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Criado com sucesso"
    } else {
        Write-Host "  ✗ Falha ao criar"
        throw "Erro ao criar segredo: $Name"
    }
}

# ============================================================================
# PostgreSQL Secrets
# ============================================================================
Write-Host "`n--- PostgreSQL Database ---"

Set-KeyVaultSecret `
    -Name "postgres-host" `
    -Value "postgres" `
    -Description "PostgreSQL hostname"

Set-KeyVaultSecret `
    -Name "postgres-port" `
    -Value "5432" `
    -Description "PostgreSQL port"

Set-KeyVaultSecret `
    -Name "postgres-user" `
    -Value "dataplatform" `
    -Description "PostgreSQL username"

Set-KeyVaultSecret `
    -Name "postgres-password" `
    -Value "Bomgado@233751" `
    -Description "PostgreSQL password"

Set-KeyVaultSecret `
    -Name "postgres-airflow-db" `
    -Value "airflow_db" `
    -Description "Airflow database name"

Set-KeyVaultSecret `
    -Name "postgres-superset-db" `
    -Value "superset_db" `
    -Description "Superset database name"

# ============================================================================
# Redis Secrets
# ============================================================================
Write-Host "`n--- Redis Cache ---"

Set-KeyVaultSecret `
    -Name "redis-host" `
    -Value "redis" `
    -Description "Redis hostname"

Set-KeyVaultSecret `
    -Name "redis-port" `
    -Value "6379" `
    -Description "Redis port"

Set-KeyVaultSecret `
    -Name "redis-password" `
    -Value "Bomgado@233751" `
    -Description "Redis password"

# ============================================================================
# Airflow Secrets
# ============================================================================
Write-Host "`n--- Apache Airflow ---"

Set-KeyVaultSecret `
    -Name "airflow-fernet-key" `
    -Value "q7ItG0Si3Fyw3aqfk-X9vcq9h_twZoWNmJJ_pRIFYkk" `
    -Description "Airflow Fernet encryption key"

Set-KeyVaultSecret `
    -Name "airflow-webserver-secret" `
    -Value "3Pz-SW0QLF8h9lR7jq8__6p9fMEwfIk_xfifkyoYRKs" `
    -Description "Airflow webserver secret key"

Set-KeyVaultSecret `
    -Name "airflow-admin-username" `
    -Value "admin" `
    -Description "Airflow admin username"

Set-KeyVaultSecret `
    -Name "airflow-admin-password" `
    -Value "admin123" `
    -Description "Airflow admin password"

Set-KeyVaultSecret `
    -Name "airflow-admin-firstname" `
    -Value "Admin" `
    -Description "Airflow admin first name"

Set-KeyVaultSecret `
    -Name "airflow-admin-lastname" `
    -Value "User" `
    -Description "Airflow admin last name"

Set-KeyVaultSecret `
    -Name "airflow-admin-email" `
    -Value "admin@bomgado.com.br" `
    -Description "Airflow admin email"

# ============================================================================
# Superset Secrets
# ============================================================================
Write-Host "`n--- Apache Superset ---"

Set-KeyVaultSecret `
    -Name "superset-secret-key" `
    -Value "YOUR_OWN_RANDOM_GENERATED_SECRET_KEY_CHANGE_THIS_IMMEDIATELY_$(Get-Random)" `
    -Description "Superset Flask secret key"

Set-KeyVaultSecret `
    -Name "superset-admin-username" `
    -Value "admin" `
    -Description "Superset admin username"

Set-KeyVaultSecret `
    -Name "superset-admin-password" `
    -Value "admin123" `
    -Description "Superset admin password"

Set-KeyVaultSecret `
    -Name "superset-admin-firstname" `
    -Value "Admin" `
    -Description "Superset admin first name"

Set-KeyVaultSecret `
    -Name "superset-admin-lastname" `
    -Value "User" `
    -Description "Superset admin last name"

Set-KeyVaultSecret `
    -Name "superset-admin-email" `
    -Value "admin@bomgado.com.br" `
    -Description "Superset admin email"

# ============================================================================
# Azure Entra ID (OAuth) Secrets
# ============================================================================
Write-Host "`n--- Azure Entra ID OAuth ---"

Set-KeyVaultSecret `
    -Name "azure-tenant-id" `
    -Value "0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035" `
    -Description "Azure Entra ID Tenant ID"

Set-KeyVaultSecret `
    -Name "azure-client-id-superset" `
    -Value "d4ef29a3-49da-4ca1-a8a8-e8f786123224" `
    -Description "Azure App Registration Client ID (Superset)"

Set-KeyVaultSecret `
    -Name "azure-client-id-airflow" `
    -Value "d4ef29a3-49da-4ca1-a8a8-e8f786123224" `
    -Description "Azure App Registration Client ID (Airflow)"

Set-KeyVaultSecret `
    -Name "azure-client-secret" `
    -Value "SEU_CLIENT_SECRET_AQUI" `
    -Description "Azure App Registration Client Secret (OBTENHA DO AZURE PORTAL)"

Set-KeyVaultSecret `
    -Name "public-domain" `
    -Value "bi.bomgado.com.br" `
    -Description "Public domain for OAuth callbacks"

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n======================================================================"
Write-Host " Resumo"
Write-Host "======================================================================"
Write-Host "  ✓ 25 segredos criados com sucesso no Key Vault: $VAULT_NAME"
Write-Host ""
Write-Host "Próximos passos:"
Write-Host "  1. Configure Managed Identity na VM Azure"
Write-Host "  2. Teste: python3 shared/check_vault_health.py"
Write-Host "  3. Deploy: bash deploy-keyvault.sh"
Write-Host ""
Write-Host "Documentação completa: AZURE_KEYVAULT_SETUP.md"
Write-Host "======================================================================"
