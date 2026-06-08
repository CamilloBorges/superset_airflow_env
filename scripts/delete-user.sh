#!/bin/bash
# Remove um usuário LDAP

source .env

read -p "Username a remover: " username

USER_DN=$(sudo docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "ou=users,dc=bomgado,dc=local" \
    "(uid=$username)" dn 2>/dev/null | grep "^dn:" | cut -d ' ' -f2-)

if [ -z "$USER_DN" ]; then
    echo "❌ Usuário $username não encontrado!"
    exit 1
fi

echo "⚠️  Confirma remoção de: $USER_DN? [s/N]"
read confirm

if [ "$confirm" = "s" ] || [ "$confirm" = "S" ]; then
    sudo docker exec openldap ldapdelete -x -H ldap://localhost:389 \
        -D "cn=admin,dc=bomgado,dc=local" \
        -w "${LDAP_ADMIN_PASSWORD}" \
        "$USER_DN"
    echo "✅ Usuário removido com sucesso!"
else
    echo "Operação cancelada."
fi
