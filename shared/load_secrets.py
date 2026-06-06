#!/usr/bin/env python3
"""
Azure Key Vault Secret Loader
Carrega segredos do Azure Key Vault e exporta como variáveis de ambiente.

Usage:
    python load_secrets.py --export    # Para source em shell scripts
    python load_secrets.py             # Modo interativo (valores mascarados)
"""
import os
import sys
from urllib.parse import quote_plus

try:
    from azure.identity import DefaultAzureCredential, ManagedIdentityCredential, ClientSecretCredential
    from azure.keyvault.secrets import SecretClient
except ImportError:
    print("ERROR: Azure SDK not installed. Run: pip install azure-identity azure-keyvault-secrets", file=sys.stderr)
    sys.exit(1)

VAULT_URL = os.getenv("AZURE_KEYVAULT_URL", "https://bomgado-vault.vault.azure.net/")

# Mapeamento: nome no Key Vault → nome da variável de ambiente
SECRET_MAPPING = {
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
    "airflow-admin-firstname": "AIRFLOW_ADMIN_FIRSTNAME",
    "airflow-admin-lastname": "AIRFLOW_ADMIN_LASTNAME",
    "airflow-admin-email": "AIRFLOW_ADMIN_EMAIL",
    
    # Superset
    "superset-secret-key": "SUPERSET_SECRET_KEY",
    "superset-admin-username": "SUPERSET_ADMIN_USERNAME",
    "superset-admin-password": "SUPERSET_ADMIN_PASSWORD",
    "superset-admin-firstname": "SUPERSET_ADMIN_FIRSTNAME",
    "superset-admin-lastname": "SUPERSET_ADMIN_LASTNAME",
    "superset-admin-email": "SUPERSET_ADMIN_EMAIL",
    
    # Azure OAuth
    "azure-tenant-id": "AZURE_TENANT_ID",
    "azure-superset-client-id": "AZURE_SUPERSET_CLIENT_ID",
    "azure-superset-client-secret": "AZURE_SUPERSET_CLIENT_SECRET",
    "azure-airflow-client-id": "AZURE_AIRFLOW_CLIENT_ID",
    "azure-airflow-client-secret": "AZURE_AIRFLOW_CLIENT_SECRET",
}


def get_credential():
    """
    Retorna credencial apropriada para autenticação no Azure.
    Ordem de tentativa:
    1. Managed Identity (produção)
    2. Service Principal (desenvolvimento)
    3. DefaultAzureCredential (fallback)
    """
    # Opção 1: Managed Identity (produção na VM Azure)
    try:
        credential = ManagedIdentityCredential()
        # Testar se funciona
        credential.get_token("https://vault.azure.net/.default")
        print("✓ Using Managed Identity", file=sys.stderr)
        return credential
    except Exception:
        pass
    
    # Opção 2: Service Principal (desenvolvimento)
    client_id = os.getenv("AZURE_CLIENT_ID")
    client_secret = os.getenv("AZURE_CLIENT_SECRET")
    tenant_id = os.getenv("AZURE_TENANT_ID")
    
    if client_id and client_secret and tenant_id:
        print("✓ Using Service Principal", file=sys.stderr)
        return ClientSecretCredential(
            tenant_id=tenant_id,
            client_id=client_id,
            client_secret=client_secret
        )
    
    # Opção 3: DefaultAzureCredential (Azure CLI, VS Code, etc)
    print("✓ Using DefaultAzureCredential", file=sys.stderr)
    return DefaultAzureCredential()


def load_secrets():
    """
    Carrega todos os segredos do Key Vault.
    Retorna dict com variáveis de ambiente.
    """
    print(f"Connecting to Key Vault: {VAULT_URL}", file=sys.stderr)
    
    try:
        credential = get_credential()
        client = SecretClient(vault_url=VAULT_URL, credential=credential)
        
        secrets = {}
        failed = []
        
        for vault_name, env_name in SECRET_MAPPING.items():
            try:
                secret = client.get_secret(vault_name)
                secrets[env_name] = secret.value
                print(f"✓ Loaded {vault_name} → {env_name}", file=sys.stderr)
            except Exception as e:
                failed.append(f"{vault_name}: {str(e)}")
                print(f"✗ Failed to load {vault_name}: {e}", file=sys.stderr)
        
        # Criar variáveis derivadas
        if "POSTGRES_PASSWORD" in secrets:
            secrets["POSTGRES_PASSWORD_URLENCODED"] = quote_plus(secrets["POSTGRES_PASSWORD"])
            print("✓ Generated POSTGRES_PASSWORD_URLENCODED", file=sys.stderr)
        
        if "REDIS_PASSWORD" in secrets:
            secrets["REDIS_PASSWORD_URLENCODED"] = quote_plus(secrets["REDIS_PASSWORD"])
            print("✓ Generated REDIS_PASSWORD_URLENCODED", file=sys.stderr)
        
        # Adicionar variáveis não-sensíveis do ambiente
        for key in ["COMPOSE_PROJECT_NAME", "TIMEZONE", "PUBLIC_DOMAIN", "AIRFLOW_EXECUTOR",
                    "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION", "AIRFLOW__CORE__LOAD_EXAMPLES",
                    "AIRFLOW__CORE__PARALLELISM", "AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG",
                    "AIRFLOW__WEBSERVER__EXPOSE_CONFIG", "AIRFLOW_UID",
                    "SUPERSET_EXTERNAL_PORT", "AIRFLOW_EXTERNAL_PORT", "HOP_EXTERNAL_PORT"]:
            if key in os.environ:
                secrets[key] = os.environ[key]
        
        if failed:
            print(f"\n⚠️  {len(failed)} segredos falharam ao carregar", file=sys.stderr)
        
        print(f"\n✓ Successfully loaded {len(secrets)} secrets/variables", file=sys.stderr)
        return secrets
        
    except Exception as e:
        print(f"\n❌ ERROR: Failed to connect to Key Vault: {e}", file=sys.stderr)
        print("Verify:", file=sys.stderr)
        print("  1. Key Vault URL is correct", file=sys.stderr)
        print("  2. Authentication is configured (Managed Identity or Service Principal)", file=sys.stderr)
        print("  3. Permissions are granted (get, list secrets)", file=sys.stderr)
        sys.exit(1)


def export_as_env():
    """Exporta segredos no formato shell (para eval em scripts)"""
    secrets = load_secrets()
    for key, value in secrets.items():
        # Escapar aspas e caracteres especiais
        safe_value = value.replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')
        print(f'export {key}="{safe_value}"')


def show_interactive():
    """Modo interativo: mostra valores mascarados"""
    secrets = load_secrets()
    
    print("\n" + "="*60)
    print(" Segredos carregados do Azure Key Vault")
    print("="*60)
    
    categories = {
        "PostgreSQL": ["POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_HOST", "POSTGRES_PORT", 
                       "POSTGRES_AIRFLOW_DB", "POSTGRES_SUPERSET_DB", "POSTGRES_PASSWORD_URLENCODED"],
        "Redis": ["REDIS_HOST", "REDIS_PORT", "REDIS_PASSWORD", "REDIS_PASSWORD_URLENCODED"],
        "Airflow": ["AIRFLOW__CORE__FERNET_KEY", "AIRFLOW__WEBSERVER__SECRET_KEY", 
                    "AIRFLOW_ADMIN_USERNAME", "AIRFLOW_ADMIN_PASSWORD"],
        "Superset": ["SUPERSET_SECRET_KEY", "SUPERSET_ADMIN_USERNAME", "SUPERSET_ADMIN_PASSWORD"],
        "Azure OAuth": ["AZURE_TENANT_ID", "AZURE_SUPERSET_CLIENT_ID", "AZURE_SUPERSET_CLIENT_SECRET",
                        "AZURE_AIRFLOW_CLIENT_ID", "AZURE_AIRFLOW_CLIENT_SECRET"],
    }
    
    for category, keys in categories.items():
        print(f"\n{category}:")
        for key in keys:
            if key in secrets:
                value = secrets[key]
                # Mascarar valor: mostrar apenas últimos 4 caracteres
                if len(value) > 8:
                    masked = "***" + value[-4:]
                else:
                    masked = "***"
                print(f"  {key:40s} = {masked}")
    
    print("\n" + "="*60)
    print(f"Total: {len(secrets)} variáveis carregadas")
    print("="*60 + "\n")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--export":
        export_as_env()
    else:
        show_interactive()
