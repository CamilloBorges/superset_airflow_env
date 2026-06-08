#!/bin/bash
# Lista todos os usuários LDAP

source .env

sudo docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "ou=users,dc=bomgado,dc=local" \
    "(objectClass=inetOrgPerson)" cn uid mail 2>/dev/null | \
    grep -E "^(dn:|cn:|uid:|mail:)" | \
    awk 'BEGIN {print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"} \
         /^dn:/ {if (NR>1) print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; print} \
         !/^dn:/ {print} \
         END {print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"}'
