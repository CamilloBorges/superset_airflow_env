#!/bin/bash
# Lista grupos LDAP e seus membros

source .env

sudo docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "ou=groups,dc=bomgado,dc=local" \
    "(objectClass=groupOfNames)" cn description member 2>/dev/null | \
    grep -E "^(dn:|cn:|description:|member:)" | \
    awk 'BEGIN {print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"} \
         /^dn:/ {if (NR>1) print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; print} \
         !/^dn:/ {print} \
         END {print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"}'
