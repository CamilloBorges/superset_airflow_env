#!/usr/bin/env python3
"""
Script Helper: Gerador de Chaves e Secrets
============================================

Este script gera todas as chaves e secrets necessários para o arquivo .env

Uso:
    python generate_secrets.py
"""

import secrets
import string
from cryptography.fernet import Fernet


def generate_random_string(length=50):
    """Gera uma string aleatória segura"""
    alphabet = string.ascii_letters + string.digits + string.punctuation
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def generate_fernet_key():
    """Gera uma chave Fernet válida para o Airflow"""
    return Fernet.generate_key().decode()


def generate_alphanumeric(length=32):
    """Gera uma string alfanumérica"""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def main():
    print("=" * 70)
    print("GERADOR DE CHAVES E SECRETS - Data Platform")
    print("=" * 70)
    print()
    
    print("Copie os valores abaixo para o seu arquivo .env:\n")
    
    print("# PostgreSQL")
    print(f"POSTGRES_PASSWORD={generate_alphanumeric(32)}")
    print()
    
    print("# Redis")
    print(f"REDIS_PASSWORD={generate_alphanumeric(32)}")
    print()
    
    print("# Airflow - Fernet Key (para criptografia de senhas)")
    print(f"AIRFLOW__CORE__FERNET_KEY={generate_fernet_key()}")
    print()
    
    print("# Airflow - Webserver Secret Key")
    print(f"AIRFLOW__WEBSERVER__SECRET_KEY={generate_random_string(50)}")
    print()
    
    print("# Superset - Secret Key (mínimo 42 caracteres)")
    print(f"SUPERSET_SECRET_KEY={generate_random_string(50)}")
    print()
    
    print("=" * 70)
    print("⚠️  IMPORTANTE:")
    print("   - Guarde esses valores em local seguro")
    print("   - Nunca commite o arquivo .env no Git")
    print("   - Use o .env.example apenas como template")
    print("=" * 70)


if __name__ == "__main__":
    try:
        main()
    except ImportError as e:
        print("❌ Erro: Biblioteca 'cryptography' não encontrada.")
        print("\nInstale com:")
        print("  pip install cryptography")
        print("\nOu execute via Docker:")
        print('  docker run --rm python:3.11-slim sh -c "pip install cryptography && python - << EOF')
        print(open(__file__).read())
        print('EOF"')
