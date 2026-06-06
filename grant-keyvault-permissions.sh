#!/bin/bash
################################################################################
# Conceder permissões ao usuário atual no Azure Key Vault
################################################################################

VAULT_NAME="bomgado-vault"
RESOURCE_GROUP="bi"
SUBSCRIPTION="4d25cd7c-b242-491e-8c40-afd1fe427667"

echo "======================================================================"
echo " Configurando Permissões no Key Vault"
echo " Vault: $VAULT_NAME"
echo " Resource Group: $RESOURCE_GROUP"
echo "======================================================================"

# Obter o ID do usuário atual
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "✓ Usuário logado Object ID: $USER_OBJECT_ID"

# Conceder role Key Vault Secrets Officer
echo ""
echo "Concedendo role 'Key Vault Secrets Officer'..."
az role assignment create \
    --role "Key Vault Secrets Officer" \
    --assignee-object-id "$USER_OBJECT_ID" \
    --assignee-principal-type "User" \
    --scope "/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$VAULT_NAME"

if [ $? -eq 0 ]; then
    echo "✓ Permissões concedidas com sucesso!"
    echo ""
    echo "Aguarde 1-2 minutos para propagação das permissões..."
    echo "Depois execute: bash setup-keyvault-secrets-ubuntu.sh"
else
    echo "❌ Falha ao conceder permissões"
    echo ""
    echo "Execute manualmente no portal Azure:"
    echo "1. Acesse https://portal.azure.com"
    echo "2. Key Vault → bomgado-vault → Access control (IAM)"
    echo "3. Add role assignment → Key Vault Secrets Officer"
    echo "4. Selecione seu usuário"
fi

echo "======================================================================"
