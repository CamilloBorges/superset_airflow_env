# 🔐 Azure Key Vault - Guia Rápido

Este guia mostra como configurar e usar Azure Key Vault para gerenciar segredos da plataforma.

## 📋 Pré-requisitos

- Azure CLI instalado: https://docs.microsoft.com/cli/azure/install-azure-cli
- Python 3.8+ com pip
- Permissões de administrador no Azure Subscription
- Key Vault `bomgado-vault` já criado

## 🏢 Arquitetura Multi-Tenant

Este projeto usa **2 tenants Azure separados**:

| Tenant | ID | Uso |
|--------|----|----|
| **bomgado.com** | `0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035` | Azure Entra ID (SSO/OAuth) |
| **bomgado.com.br** | `e97132bc-f926-4fba-9f6e-0379c8f25b23` | Infraestrutura (VMs, Key Vault) |

⚠️ **Importante**: O Key Vault está no tenant **bomgado.com.br** (infraestrutura)

## 🚀 Setup Rápido (3 passos)

### Passo 1: Criar Segredos no Key Vault

```bash
# Execute apenas UMA VEZ
bash setup-keyvault-secrets.sh
```

Este script:
- Faz login no Azure
- Cria todos os 25 segredos necessários
- Configura valores padrão (você pode alterar depois)

### Passo 2: Configurar Autenticação

Escolha **UMA** das opções:

#### Opção A: Managed Identity (Produção - VM Azure) ✅ Recomendado

```bash
# 1. Habilitar Managed Identity na VM
az vm identity assign --name bomgado --resource-group <SEU_RESOURCE_GROUP>

# 2. Obter o Principal ID
VM_PRINCIPAL=$(az vm identity show \
    --name bomgado \
    --resource-group <SEU_RESOURCE_GROUP> \
    --query principalId -o tsv)

# 3. Conceder permissões ao Key Vault
az keyvault set-policy \
    --name bomgado-vault \
    --object-id $VM_PRINCIPAL \
    --secret-permissions get list
```

#### Opção B: Service Principal (Desenvolvimento Local)

```bash
# 1. Criar Service Principal
SP_INFO=$(az ad sp create-for-rbac \
    --name bomgado-dataplatform-sp \
    --role Reader)

# 2. Anotar as credenciais retornadas
echo $SP_INFO
# {
#   "appId": "xxx",
#   "password": "yyy",
#   "tenant": "zzz"
# }

# 3. Conceder permissões
az keyvault set-policy \
    --name bomgado-vault \
    --spn <appId_acima> \
    --secret-permissions get list

# 4. Adicionar credenciais no .env (APENAS desenvolvimento)
cat >> .env << EOF
AZURE_CLIENT_ID=<appId>
AZURE_CLIENT_SECRET=<password>
AZURE_TENANT_ID=e97132bc-f926-4fba-9f6e-0379c8f25b23  # bomgado.com.br (infraestrutura)
EOF
```

### Passo 3: Testar e Deploy

```bash
# 1. Instalar dependências
pip3 install -r shared/requirements.txt

# 2. Testar carregamento de segredos
python3 shared/load_secrets.py

# Deve mostrar:
# ✓ Loaded postgres-user → POSTGRES_USER
# ✓ Loaded postgres-password → POSTGRES_PASSWORD
# ...
# ✓ Successfully loaded 28 secrets/variables

# 3. Deploy completo
bash deploy-keyvault.sh
```

## 📖 Arquivos Criados

| Arquivo | Descrição |
|---------|-----------|
| `AZURE_KEYVAULT_SETUP.md` | Documentação completa |
| `shared/load_secrets.py` | Script Python para carregar segredos |
| `shared/requirements.txt` | Dependências Azure SDK |
| `setup-keyvault-secrets.sh` | Cria todos os segredos no Vault |
| `deploy-keyvault.sh` | Deploy completo com Key Vault |

## 🔍 Comandos Úteis

### Ver todos os segredos no Vault

```bash
az keyvault secret list --vault-name bomgado-vault --query "[].name" -o table
```

### Ver valor de um segredo específico

```bash
az keyvault secret show --vault-name bomgado-vault --name postgres-password --query "value" -o tsv
```

### Atualizar um segredo

```bash
az keyvault secret set \
    --vault-name bomgado-vault \
    --name postgres-password \
    --value "NOVA_SENHA_FORTE"
```

### Rotacionar senhas

```bash
# 1. Atualizar no Key Vault
az keyvault secret set --vault-name bomgado-vault --name postgres-password --value "NOVA_SENHA"

# 2. Atualizar senha no PostgreSQL
docker exec -it postgres psql -U dataplatform -c "ALTER USER dataplatform WITH PASSWORD 'NOVA_SENHA';"

# 3. Reiniciar serviços
docker compose restart
```

## 🛠️ Troubleshooting

### Erro: "Failed to connect to Key Vault"

```bash
# Verificar permissões
az keyvault show --name bomgado-vault --query "properties.accessPolicies[].permissions"

# Verificar autenticação
az account show
```

### Erro: "Secret not found"

```bash
# Listar todos os segredos
az keyvault secret list --vault-name bomgado-vault -o table

# Criar segredo faltante
az keyvault secret set --vault-name bomgado-vault --name <nome> --value "<valor>"
```

### Testar autenticação Python

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url="https://bomgado-vault.vault.azure.net/",
    credential=credential
)

# Testar
secret = client.get_secret("postgres-password")
print(f"✓ Conectado! Senha termina com: ...{secret.value[-4:]}")
```

## 📚 Próximos Passos

1. ✅ Executar `setup-keyvault-secrets.sh`
2. ✅ Configurar Managed Identity na VM
3. ✅ Testar `python3 shared/load_secrets.py`
4. ✅ Executar `deploy-keyvault.sh`
5. ✅ Remover segredos do `.env` (manter apenas variáveis públicas)
6. ✅ Adicionar ao `.gitignore`: `.env`, `*.backup`

## 🔒 Segurança

- ✅ Segredos **nunca** aparecem em logs
- ✅ Rotação de senhas **sem redeploy**
- ✅ Audit logs de todos os acessos
- ✅ Compliance enterprise-grade
- ✅ Managed Identity = zero credenciais em código

---

**Documentação completa:** [AZURE_KEYVAULT_SETUP.md](AZURE_KEYVAULT_SETUP.md)
