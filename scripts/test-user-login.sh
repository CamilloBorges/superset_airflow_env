#!/bin/bash
# Testa login de um usuário LDAP

source .env

read -p "Username para testar: " username
read -s -p "Senha: " password
echo ""

USER_DN=$(sudo docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "ou=users,dc=bomgado,dc=local" \
    "(uid=$username)" dn 2>/dev/null | grep "^dn:" | cut -d ' ' -f2-)

if [ -z "$USER_DN" ]; then
    echo "❌ Usuário $username não encontrado!"
    exit 1
fi

if sudo docker exec openldap ldapwhoami -x -H ldap://localhost:389 \
    -D "$USER_DN" -w "$password" > /dev/null 2>&1; then
    echo "✅ Login válido! Usuário autenticado com sucesso."
else
    echo "❌ Login inválido! Verifique a senha."
fi
