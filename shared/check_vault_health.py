#!/usr/bin/env python3
"""
Azure Key Vault - Health Check
Verifica conexão e acesso aos segredos do Key Vault
"""
import sys
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = "https://bomgado-vault.vault.azure.net/"
REQUIRED_SECRETS = [
    "postgres-user",
    "postgres-password",
    "redis-password",
    "airflow-fernet-key",
    "superset-secret-key",
    "azure-tenant-id",
]

def check_vault_health():
    """Verifica saúde do Key Vault"""
    print("="*70)
    print(" Azure Key Vault - Health Check")
    print("="*70)
    print(f"\nVault URL: {VAULT_URL}\n")
    
    # Testar autenticação
    print("1. Testing Authentication...")
    try:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=VAULT_URL, credential=credential)
        print("   ✓ Authentication successful")
    except Exception as e:
        print(f"   ✗ Authentication failed: {e}")
        return False
    
    # Testar acesso aos segredos
    print("\n2. Testing Secret Access...")
    success_count = 0
    failed_secrets = []
    
    for secret_name in REQUIRED_SECRETS:
        try:
            secret = client.get_secret(secret_name)
            masked_value = "***" + secret.value[-4:] if len(secret.value) > 4 else "***"
            print(f"   ✓ {secret_name:30s} = {masked_value}")
            success_count += 1
        except Exception as e:
            print(f"   ✗ {secret_name:30s} FAILED: {str(e)[:50]}")
            failed_secrets.append(secret_name)
    
    # Listar todos os segredos disponíveis
    print("\n3. Listing All Secrets...")
    try:
        all_secrets = list(client.list_properties_of_secrets())
        print(f"   Total secrets in vault: {len(all_secrets)}")
        for secret_prop in sorted(all_secrets, key=lambda x: x.name):
            status = "✓" if secret_prop.enabled else "✗"
            print(f"   {status} {secret_prop.name}")
    except Exception as e:
        print(f"   ✗ Failed to list secrets: {e}")
    
    # Resultado final
    print("\n" + "="*70)
    print(" Summary")
    print("="*70)
    print(f"  Required secrets checked: {len(REQUIRED_SECRETS)}")
    print(f"  Successful:               {success_count}")
    print(f"  Failed:                   {len(failed_secrets)}")
    
    if failed_secrets:
        print(f"\n  ⚠️  Missing secrets: {', '.join(failed_secrets)}")
        print(f"  Run: bash setup-keyvault-secrets.sh")
        return False
    else:
        print(f"\n  ✓ All checks passed! Ready to deploy.")
        return True

if __name__ == "__main__":
    try:
        success = check_vault_health()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
        sys.exit(1)
