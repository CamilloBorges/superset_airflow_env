#!/bin/bash
################################################################################
# Configurar Managed Identity na VM Azure
################################################################################

VM_NAME="bomgado"
RESOURCE_GROUP="bi"
VAULT_NAME="bomgado-vault"
SUBSCRIPTION="4d25cd7c-b242-491e-8c40-afd1fe427667"

echo "======================================================================"
echo " Configurando Managed Identity"
echo " VM: $VM_NAME"
echo " Key Vault: $VAULT_NAME"
echo "======================================================================"

# 1. Habilitar Managed Identity na VM
echo ""
echo "1. Habilitando Managed Identity na VM..."
az vm identity assign \
    --name "$VM_NAME" \
    --resource-group "$RESOURCE_GROUP"

if [ $? -ne 0 ]; then
    echo "❌ Falha ao habilitar Managed Identity"
    exit 1
fi

echo "✓ Managed Identity habilitada"

# 2. Obter Principal ID
echo ""
echo "2. Obtendo Principal ID da VM..."
VM_PRINCIPAL=$(az vm identity show \
    --name "$VM_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query principalId -o tsv)

echo "✓ Principal ID: $VM_PRINCIPAL"

# 3. Conceder permissões ao Key Vault
echo ""
echo "3. Concedendo permissões de leitura ao Key Vault..."
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$VM_PRINCIPAL" \
    --assignee-principal-type "ServicePrincipal" \
    --scope "/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$VAULT_NAME"

if [ $? -eq 0 ]; then
    echo "✓ Permissões concedidas com sucesso!"
else
    echo "⚠️  Aviso: Pode já ter permissões ou erro ao conceder"
fi

echo ""
echo "======================================================================"
echo " ✓ Configuração Concluída!"
echo "======================================================================"
echo ""
echo "Aguarde 1-2 minutos para propagação das permissões"
echo ""
echo "Próximos passos:"
echo "  1. Enviar arquivos: scp shared/* azureuser@52.249.219.22:~/data-platform/shared/"
echo "  2. Testar: python3 shared/check_vault_health.py"
echo "  3. Deploy: bash deploy-keyvault.sh"
echo "======================================================================"
