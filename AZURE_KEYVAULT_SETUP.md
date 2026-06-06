# Azure Key Vault - Configuração e Implementação

## Visão Geral

**Vault URL:** `https://bomgado-vault.vault.azure.net/`  
**Tenant ID:** `0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035`

Este documento descreve como configurar e usar Azure Key Vault para gerenciar todos os segredos da plataforma de dados.

---

## 1. Segredos a Armazenar

### Banco de Dados PostgreSQL
| Nome do Segredo | Valor Atual | Descrição |
|----------------|-------------|-----------|
| `postgres-user` | `dataplatform` | Usuário PostgreSQL |
| `postgres-password` | `Bomgado@233751` | Senha PostgreSQL (sem encoding) |
| `postgres-host` | `postgres` | Hostname do PostgreSQL |
| `postgres-port` | `5432` | Porta PostgreSQL |
| `postgres-airflow-db` | `airflow_db` | Nome do database Airflow |
| `postgres-superset-db` | `superset_db` | Nome do database Superset |

### Redis
| Nome do Segredo | Valor Atual | Descrição |
|----------------|-------------|-----------|
| `redis-host` | `redis` | Hostname do Redis |
| `redis-port` | `6379` | Porta Redis |
| `redis-password` | `Bomgado@233751` | Senha Redis |

### Airflow
| Nome do Segredo | Valor Atual | Descrição |
|----------------|-------------|-----------|
| `airflow-fernet-key` | `q7ItG0Si3Fyw3aqfk-X9vcq9h_twZoWNmJJ_pRIFYkk` | Chave Fernet |
| `airflow-webserver-secret-key` | `3Pz-SW0QLF8h9lR7jq8__6p9fMEwfIk_xfifkyoYRKs` | Secret Key |
| `airflow-admin-username` | `admin` | Username admin |
| `airflow-admin-password` | `admin123` | Senha admin |

### Superset
| Nome do Segredo | Valor Atual | Descrição |
|----------------|-------------|-----------|
| `superset-secret-key` | (gerar novo) | Secret key do Superset |
| `superset-admin-username` | `admin` | Username admin |
| `superset-admin-password` | `admin123` | Senha admin |

### Azure Entra ID (OAuth)
| Nome do Segredo | Valor Atual | Descrição |
|----------------|-------------|-----------|
| `azure-tenant-id` | `0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035` | Tenant ID |
| `azure-superset-client-id` | `d4ef29a3-49da-4ca1-a8a8-e8f786123224` | Client ID Superset |
| `azure-superset-client-secret` | `<SEU_CLIENT_SECRET>` | Client Secret Superset (Azure Portal) |
| `azure-airflow-client-id` | `d4ef29a3-49da-4ca1-a8a8-e8f786123224` | Client ID Airflow |
| `azure-airflow-client-secret` | `<SEU_CLIENT_SECRET>` | Client Secret Airflow (Azure Portal) |

---

## 2. Criar Segredos no Azure Key Vault

### Via Azure Portal

1. Acesse: https://portal.azure.com
2. Navegue até **Key Vaults** → `bomgado-vault`
3. No menu lateral, clique em **Secrets**
4. Clique em **+ Generate/Import**
5. Para cada segredo:
   - **Upload options:** Manual
   - **Name:** nome do segredo (ex: `postgres-password`)
   - **Value:** valor do segredo
   - Clique em **Create**

### Via Azure CLI

```bash
# Login
az login --tenant 0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035

# Definir variáveis
VAULT_NAME="bomgado-vault"

# PostgreSQL
az keyvault secret set --vault-name $VAULT_NAME --name postgres-user --value "dataplatform"
az keyvault secret set --vault-name $VAULT_NAME --name postgres-password --value "Bomgado@233751"
az keyvault secret set --vault-name $VAULT_NAME --name postgres-host --value "postgres"
az keyvault secret set --vault-name $VAULT_NAME --name postgres-port --value "5432"
az keyvault secret set --vault-name $VAULT_NAME --name postgres-airflow-db --value "airflow_db"
az keyvault secret set --vault-name $VAULT_NAME --name postgres-superset-db --value "superset_db"

# Redis
az keyvault secret set --vault-name $VAULT_NAME --name redis-host --value "redis"
az keyvault secret set --vault-name $VAULT_NAME --name redis-port --value "6379"
az keyvault secret set --vault-name $VAULT_NAME --name redis-password --value "Bomgado@233751"

# Airflow
az keyvault secret set --vault-name $VAULT_NAME --name airflow-fernet-key --value "q7ItG0Si3Fyw3aqfk-X9vcq9h_twZoWNmJJ_pRIFYkk"
az keyvault secret set --vault-name $VAULT_NAME --name airflow-webserver-secret-key --value "3Pz-SW0QLF8h9lR7jq8__6p9fMEwfIk_xfifkyoYRKs"
az keyvault secret set --vault-name $VAULT_NAME --name airflow-admin-username --value "admin"
az keyvault secret set --vault-name $VAULT_NAME --name airflow-admin-password --value "admin123"

# Superset
az keyvault secret set --vault-name $VAULT_NAME --name superset-secret-key --value "$(openssl rand -base64 42)"
az keyvault secret set --vault-name $VAULT_NAME --name superset-admin-username --value "admin"
az keyvault secret set --vault-name $VAULT_NAME --name superset-admin-password --value "admin123"

# Azure Entra ID
az keyvault secret set --vault-name $VAULT_NAME --name azure-tenant-id --value "0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035"
az keyvault secret set --vault-name $VAULT_NAME --name azure-superset-client-id --value "d4ef29a3-49da-4ca1-a8a8-e8f786123224"
az keyvault secret set --vault-name $VAULT_NAME --name azure-superset-client-secret --value "<SEU_CLIENT_SECRET>"
az keyvault secret set --vault-name $VAULT_NAME --name azure-airflow-client-id --value "d4ef29a3-49da-4ca1-a8a8-e8f786123224"
az keyvault secret set --vault-name $VAULT_NAME --name azure-airflow-client-secret --value "<SEU_CLIENT_SECRET>"
```

---

## 3. Configurar Acesso ao Key Vault

### Opção A: Managed Identity (Recomendado)

**Passo 1:** Habilitar System-assigned Managed Identity na VM

```bash
# Na VM Azure
az login --identity

# Obter o Principal ID da VM
VM_PRINCIPAL_ID=$(az vm identity show --name bomgado --resource-group <RESOURCE_GROUP> --query principalId -o tsv)
echo $VM_PRINCIPAL_ID
```

**Passo 2:** Conceder permissões à Managed Identity

```bash
# Do seu computador local (com permissões admin)
az keyvault set-policy \
  --name bomgado-vault \
  --object-id $VM_PRINCIPAL_ID \
  --secret-permissions get list
```

### Opção B: Service Principal (Alternativa)

**Passo 1:** Criar Service Principal

```bash
az ad sp create-for-rbac \
  --name "bomgado-dataplatform-sp" \
  --role Reader \
  --scopes /subscriptions/<SUBSCRIPTION_ID>

# Anote:
# - appId (CLIENT_ID)
# - password (CLIENT_SECRET)
# - tenant (TENANT_ID)
```

**Passo 2:** Conceder permissões ao Service Principal

```bash
az keyvault set-policy \
  --name bomgado-vault \
  --spn <CLIENT_ID> \
  --secret-permissions get list
```

**Passo 3:** Adicionar credenciais no .env

```bash
AZURE_CLIENT_ID=<appId>
AZURE_CLIENT_SECRET=<password>
AZURE_TENANT_ID=0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035
```

---

## 4. Implementação no Docker

### Instalar Azure SDK nos containers

Já incluído no `requirements.txt`:
- `azure-identity`
- `azure-keyvault-secrets`

### Criar script de inicialização `load_secrets.py`

Localização: `shared/load_secrets.py`

```python
#!/usr/bin/env python3
"""
Carrega segredos do Azure Key Vault e exporta como variáveis de ambiente.
"""
import os
import sys
from urllib.parse import quote_plus
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential, ClientSecretCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = "https://bomgado-vault.vault.azure.net/"

def get_credential():
    """Retorna credencial apropriada (Managed Identity ou Service Principal)"""
    # Tentar Managed Identity primeiro (recomendado em produção)
    try:
        return ManagedIdentityCredential()
    except Exception:
        pass
    
    # Fallback para Service Principal (desenvolvimento)
    client_id = os.getenv("AZURE_CLIENT_ID")
    client_secret = os.getenv("AZURE_CLIENT_SECRET")
    tenant_id = os.getenv("AZURE_TENANT_ID")
    
    if client_id and client_secret and tenant_id:
        return ClientSecretCredential(
            tenant_id=tenant_id,
            client_id=client_id,
            client_secret=client_secret
        )
    
    # Fallback para DefaultAzureCredential
    return DefaultAzureCredential()

def load_secrets():
    """Carrega todos os segredos do Key Vault"""
    try:
        credential = get_credential()
        client = SecretClient(vault_url=VAULT_URL, credential=credential)
        
        # Mapear segredos do Vault para variáveis de ambiente
        secret_mapping = {
            # PostgreSQL
            "postgres-user": "POSTGRES_USER",
            "postgres-password": "POSTGRES_PASSWORD",
            "postgres-host": "POSTGRES_HOST",
            "postgres-port": "POSTGRES_PORT",
            "postgres-airflow-db": "POSTGRES_AIRFLOW_DB",
            "postgres-superset-db": "POSTGRES_SUPERSET_DB",
            
            # Redis
            "redis-host": "REDIS_HOST",
            "redis-port": "REDIS_PORT",
            "redis-password": "REDIS_PASSWORD",
            
            # Airflow
            "airflow-fernet-key": "AIRFLOW__CORE__FERNET_KEY",
            "airflow-webserver-secret-key": "AIRFLOW__WEBSERVER__SECRET_KEY",
            "airflow-admin-username": "AIRFLOW_ADMIN_USERNAME",
            "airflow-admin-password": "AIRFLOW_ADMIN_PASSWORD",
            
            # Superset
            "superset-secret-key": "SUPERSET_SECRET_KEY",
            "superset-admin-username": "SUPERSET_ADMIN_USERNAME",
            "superset-admin-password": "SUPERSET_ADMIN_PASSWORD",
            
            # Azure OAuth
            "azure-tenant-id": "AZURE_TENANT_ID",
            "azure-superset-client-id": "AZURE_SUPERSET_CLIENT_ID",
            "azure-superset-client-secret": "AZURE_SUPERSET_CLIENT_SECRET",
            "azure-airflow-client-id": "AZURE_AIRFLOW_CLIENT_ID",
            "azure-airflow-client-secret": "AZURE_AIRFLOW_CLIENT_SECRET",
        }
        
        secrets = {}
        for vault_name, env_name in secret_mapping.items():
            try:
                secret = client.get_secret(vault_name)
                secrets[env_name] = secret.value
                print(f"✓ Loaded {vault_name}", file=sys.stderr)
            except Exception as e:
                print(f"✗ Failed to load {vault_name}: {e}", file=sys.stderr)
        
        # Criar POSTGRES_PASSWORD_URLENCODED automaticamente
        if "POSTGRES_PASSWORD" in secrets:
            secrets["POSTGRES_PASSWORD_URLENCODED"] = quote_plus(secrets["POSTGRES_PASSWORD"])
        
        return secrets
        
    except Exception as e:
        print(f"ERROR: Failed to connect to Key Vault: {e}", file=sys.stderr)
        sys.exit(1)

def export_as_env():
    """Exporta segredos como variáveis de ambiente"""
    secrets = load_secrets()
    for key, value in secrets.items():
        print(f'export {key}="{value}"')

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--export":
        export_as_env()
    else:
        # Modo interativo: imprime valores
        secrets = load_secrets()
        print("\n=== Segredos carregados ===")
        for key in sorted(secrets.keys()):
            masked = "***" + secrets[key][-4:] if len(secrets[key]) > 4 else "***"
            print(f"{key}={masked}")
```

### Atualizar Dockerfiles para instalar Azure SDK

**Para Superset** (`superset/Dockerfile`):
```dockerfile
# Adicionar após pip install
RUN pip install --target=/app/.venv/lib/python3.10/site-packages \
    azure-identity \
    azure-keyvault-secrets
```

**Para Airflow** (usar imagem oficial que já tem suporte):
```yaml
# docker-compose.yml - adicionar no x-airflow-common
pip:
  - azure-identity
  - azure-keyvault-secrets
```

---

## 5. Atualizar .env

Simplificar `.env` removendo segredos:

```bash
# =============================================================================
# AZURE KEY VAULT - Autenticação
# =============================================================================
AZURE_KEYVAULT_URL=https://bomgado-vault.vault.azure.net/

# Opção 1: Managed Identity (produção - deixe vazio)
# As credenciais serão obtidas automaticamente da VM

# Opção 2: Service Principal (desenvolvimento)
# AZURE_CLIENT_ID=<service-principal-app-id>
# AZURE_CLIENT_SECRET=<service-principal-password>
# AZURE_TENANT_ID=0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035

# =============================================================================
# CONFIGURAÇÕES GERAIS (não-sensíveis)
# =============================================================================
COMPOSE_PROJECT_NAME=data-platform
TIMEZONE=America/Sao_Paulo
PUBLIC_DOMAIN=bi.bomgado.com.br

# Portas externas
SUPERSET_EXTERNAL_PORT=8088
AIRFLOW_EXTERNAL_PORT=8080
HOP_EXTERNAL_PORT=8081
```

---

## 6. Script de Deployment Atualizado

```bash
#!/bin/bash
# deploy.sh - Deployment com Key Vault

set -e

echo "=== Carregando segredos do Azure Key Vault ==="
eval $(python3 shared/load_secrets.py --export)

echo "=== Iniciando containers ==="
docker compose up -d

echo "=== Deployment concluído ==="
```

---

## 7. Vantagens da Implementação

✅ **Segurança:**
- Senhas nunca expostas em arquivos
- Rotação de segredos sem redeploy
- Audit logs de acesso

✅ **Simplicidade:**
- Sem necessidade de URL encoding manual
- Gerenciamento centralizado
- Fácil rotação de credenciais

✅ **Compliance:**
- Atende requisitos de segurança empresarial
- Separação de responsabilidades
- Rastreabilidade completa

---

## 8. Próximos Passos

1. ✅ Criar segredos no Key Vault (via CLI ou Portal)
2. ✅ Configurar acesso (Managed Identity ou Service Principal)
3. ✅ Criar `shared/load_secrets.py`
4. ✅ Atualizar Dockerfiles com Azure SDK
5. ✅ Atualizar `docker-compose.yml` para usar script
6. ✅ Testar localmente
7. ✅ Deploy em produção
