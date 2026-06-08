# Guia de Migração: OAuth → LDAP

Este guia detalha os passos para migrar do ambiente anterior (Azure OAuth + Nginx) para o novo ambiente (LDAP + acesso direto via Cloudflare Tunnel).

## 📋 Resumo das Mudanças

### ❌ Removido
- **Nginx** - Reverse proxy local (Cloudflare Tunnel conecta direto aos containers)
- **Azure Entra ID OAuth** - Autenticação SSO (substituída por LDAP local)
- **Scripts Azure KeyVault** - Gerenciamento de secrets (não mais necessário)
- **authlib dependency** - Biblioteca OAuth (não mais usada)

### ✅ Adicionado
- **OpenLDAP** - Servidor LDAP local para autenticação unificada
- **phpLDAPadmin** - Interface web para gerenciar usuários/grupos
- **Mapeamento de grupos** - Sincronização automática de roles LDAP → Superset/Airflow

### 🔄 Modificado
- **Superset config** - `AUTH_TYPE = AUTH_LDAP` (era `AUTH_OAUTH`)
- **Airflow config** - `AUTH_TYPE = AUTH_LDAP` (era `AUTH_OAUTH`)
- **ProxyFix** - `x_proto=1` (era `x_proto=2` por conta Cloudflare+Nginx)
- **docker-compose.yml** - Serviços OpenLDAP/phpLDAPadmin adicionados, nginx removido
- **.env** - Variáveis LDAP adicionadas, variáveis Azure removidas

---

## 🔄 Passo a Passo da Migração

### 1. Backup do Ambiente Atual

```bash
# Backup PostgreSQL (usuários, dashboards, DAGs)
docker exec postgres pg_dumpall -U dataplatform > backup_postgres_$(date +%Y%m%d).sql

# Backup volumes
docker run --rm -v data-platform-postgres:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres_volume_backup.tar.gz -C /data .

docker run --rm -v superset_airflow_env_superset-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/superset_volume_backup.tar.gz -C /data .
```

### 2. Parar Ambiente Atual

```bash
cd /caminho/para/superset_airflow_env
docker compose down
```

### 3. Atualizar Arquivos de Configuração

```bash
# Backup configurações antigas
cp docker-compose.yml docker-compose.yml.backup
cp .env .env.backup
cp superset/config/superset_config.py superset/config/superset_config.py.backup
cp airflow/config/webserver_config.py airflow/config/webserver_config.py.backup

# Substituir pelos novos arquivos
mv docker-compose.new.yml docker-compose.yml
mv superset/config/superset_config_ldap.py superset/config/superset_config.py
mv airflow/config/webserver_config_ldap.py airflow/config/webserver_config.py
```

### 4. Atualizar Variáveis de Ambiente (.env)

```bash
# Copiar template novo
cp .env.ldap.example .env.new

# Transferir valores essenciais do .env antigo
# MANTER (copiar valores):
grep POSTGRES_ .env.backup >> .env.new
grep REDIS_ .env.backup >> .env.new
grep SUPERSET_SECRET_KEY .env.backup >> .env.new
grep AIRFLOW__CORE__FERNET_KEY .env.backup >> .env.new
grep AIRFLOW__WEBSERVER__SECRET_KEY .env.backup >> .env.new

# ADICIONAR (novos valores):
# Edite .env.new e configure:
nano .env.new
```

**Configurar estas novas variáveis no .env.new:**
```bash
# LDAP
LDAP_ORGANISATION=Bomgado Data Platform
LDAP_DOMAIN=bomgado.local
LDAP_BASE_DN=dc=bomgado,dc=local
LDAP_ADMIN_PASSWORD=SuaSenhaForteAqui123!
LDAP_CONFIG_PASSWORD=SenhaConfigForte456!
LDAP_READONLY_PASSWORD=SenhaReadOnly789!
LDAP_HOST=openldap
LDAP_PORT=389
LDAP_BIND_DN=cn=admin,dc=bomgado,dc=local
LDAP_BIND_PASSWORD=${LDAP_ADMIN_PASSWORD}

# Portas LDAP
LDAP_EXTERNAL_PORT=389
LDAP_ADMIN_EXTERNAL_PORT=8082
```

**REMOVER (deletar linhas):**
```bash
# Não copie estas variáveis (obsoletas):
# AZURE_TENANT_ID
# AZURE_SUPERSET_CLIENT_ID
# AZURE_SUPERSET_CLIENT_SECRET
# AZURE_AIRFLOW_CLIENT_ID
# AZURE_AIRFLOW_CLIENT_SECRET
```

```bash
# Ativar novo .env
mv .env.new .env
```

### 5. Remover Diretório nginx

```bash
# Nginx não é mais necessário (Cloudflare Tunnel conecta direto)
rm -rf nginx/
```

### 6. Remover Scripts Azure

```bash
# Limpar scripts obsoletos
rm -f AZURE_KEYVAULT_SETUP.md
rm -f KEYVAULT_QUICKSTART.md
rm -f configure-managed-identity.sh
rm -f deploy-keyvault.sh
rm -f grant-keyvault-permissions.sh
rm -f setup-keyvault-secrets*.sh
rm -f setup-keyvault-secrets.ps1
rm -f fix_csrf.py
rm -f superset_session_fix.py
rm -f .env.example  # Usar .env.ldap.example ao invés
```

### 7. Inicializar Novo Ambiente

```bash
# Subir containers (LDAP será inicializado primeiro)
docker compose up -d

# Acompanhar logs de inicialização
docker compose logs -f
```

**Aguardar:**
- OpenLDAP: ~30 segundos
- PostgreSQL: ~10 segundos
- Redis: ~5 segundos
- Superset init: ~2 minutos
- Airflow init: ~2 minutos

### 8. Verificar Saúde dos Serviços

```bash
# Ver status de todos os containers
docker compose ps

# Todos devem estar "healthy" ou "running"
# Aguardar até que health checks passem (pode levar 3-5 minutos)
```

### 9. Restaurar Dados (se necessário)

```bash
# Restaurar PostgreSQL backup
docker exec -i postgres psql -U dataplatform < backup_postgres_20260608.sql
```

### 10. Criar Usuários no LDAP

Acesse phpLDAPadmin: https://ldap.bomgado.com.br

**Login:**
- DN: `cn=admin,dc=bomgado,dc=local`
- Password: `${LDAP_ADMIN_PASSWORD}` (do .env)

**Adicionar usuário exemplo:**
1. Navegue até `ou=users,dc=bomgado,dc=local`
2. Create new entry → inetOrgPerson
3. Preencha:
   - CN: `Admin User`
   - SN: `User`
   - UID: `admin` (username para login)
   - Mail: `admin@bomgado.local`
   - Given Name: `Admin`
   - User Password: `admin123` (trocar depois!)
4. Add objectClass: `posixAccount`
5. Adicionar:
   - uidNumber: `10000`
   - gidNumber: `10000`
   - homeDirectory: `/home/admin`
   - loginShell: `/bin/bash`

**Adicionar ao grupo admins:**
1. Navegue até `cn=admins,ou=groups,dc=bomgado,dc=local`
2. Modify group → add member
3. Member: `cn=Admin User,ou=users,dc=bomgado,dc=local`

### 11. Testar Autenticação

**Superset:**
1. Acesse: https://bi.bomgado.com.br
2. Login: `admin` / `admin123`
3. Verificar role: Admin

**Airflow:**
1. Acesse: https://airflow.bomgado.com.br
2. Login: `admin` / `admin123`
3. Verificar role: Admin

### 12. Atualizar Cloudflare Tunnel

**Configuração antiga (com Nginx):**
```yaml
ingress:
  - hostname: bi.bomgado.com.br
    service: http://localhost:80  # Nginx porta 80
```

**Configuração nova (direto):**
```yaml
ingress:
  # Superset - direto na porta 8088
  - hostname: bi.bomgado.com.br
    service: http://localhost:8088
    
  # Airflow - direto na porta 8080
  - hostname: airflow.bomgado.com.br
    service: http://localhost:8080
    
  # Hop - direto na porta 8081
  - hostname: hop.bomgado.com.br
    service: http://localhost:8081
    
  # phpLDAPadmin - nova porta 8082
  - hostname: ldap.bomgado.com.br
    service: http://localhost:8082
  
  - service: http_status:404
```

**Atualizar:**
```bash
# Editar config
sudo nano /root/.cloudflared/config.yml

# Reiniciar tunnel
sudo systemctl restart cloudflared

# Verificar
sudo systemctl status cloudflared
```

### 13. Validação Final

```bash
# Verificar conectividade LDAP
docker exec superset python3 -c "
from ldap3 import Server, Connection
server = Server('openldap', port=389)
conn = Connection(server, 'cn=admin,dc=bomgado,dc=local', '${LDAP_ADMIN_PASSWORD}')
print('LDAP OK' if conn.bind() else 'LDAP ERRO')
"

# Verificar logs sem erros
docker compose logs superset | grep -i error
docker compose logs airflow-webserver | grep -i error
```

---

## 🔄 Migração de Usuários

### Exportar Usuários do Superset Antigo

```bash
# Conectar no banco antigo
docker exec -i postgres psql -U dataplatform superset_db << EOF
SELECT 
    username,
    first_name,
    last_name,
    email
FROM ab_user
WHERE username NOT IN ('admin');
EOF
```

### Criar Script de Importação LDAP

```bash
#!/bin/bash
# import_users_to_ldap.sh

LDAP_ADMIN_DN="cn=admin,dc=bomgado,dc=local"
LDAP_ADMIN_PW="$LDAP_ADMIN_PASSWORD"

# Lista de usuários (username, givenName, sn, mail)
users=(
    "joao.silva:João:Silva:joao.silva@bomgado.com.br"
    "maria.santos:Maria:Santos:maria.santos@bomgado.com.br"
    # ... adicionar mais usuários
)

uid_counter=10001
for user_data in "${users[@]}"; do
    IFS=':' read -r uid given_name sn mail <<< "$user_data"
    
    cat > /tmp/${uid}.ldif <<EOF
dn: cn=${given_name} ${sn},ou=users,dc=bomgado,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: ${given_name} ${sn}
sn: ${sn}
givenName: ${given_name}
uid: ${uid}
uidNumber: ${uid_counter}
gidNumber: 10000
homeDirectory: /home/${uid}
loginShell: /bin/bash
mail: ${mail}
userPassword: TemporaryPass123!
EOF

    docker exec -i openldap ldapadd -x \
        -D "${LDAP_ADMIN_DN}" \
        -w "${LDAP_ADMIN_PW}" \
        -f /tmp/${uid}.ldif
    
    ((uid_counter++))
done
```

---

## 🛠️ Rollback (em caso de problemas)

```bash
# Parar novo ambiente
docker compose down

# Restaurar arquivos antigos
mv docker-compose.yml.backup docker-compose.yml
mv .env.backup .env
mv superset/config/superset_config.py.backup superset/config/superset_config.py
mv airflow/config/webserver_config.py.backup airflow/config/webserver_config.py

# Restaurar diretório nginx (se backup existe)
# cp -r nginx.backup nginx/

# Subir ambiente antigo
docker compose up -d

# Restaurar Cloudflare Tunnel config antigo
sudo nano /root/.cloudflared/config.yml
sudo systemctl restart cloudflared
```

---

## 📊 Checklist de Migração

- [ ] Backup PostgreSQL criado
- [ ] Backup volumes criado
- [ ] Arquivos de configuração atualizados
- [ ] .env atualizado com variáveis LDAP
- [ ] Variáveis Azure removidas do .env
- [ ] Diretório nginx removido
- [ ] Scripts Azure removidos
- [ ] docker-compose.yml atualizado
- [ ] Containers iniciados com sucesso
- [ ] Health checks OK em todos os serviços
- [ ] OpenLDAP respondendo
- [ ] phpLDAPadmin acessível
- [ ] Usuários criados no LDAP
- [ ] Grupos configurados no LDAP
- [ ] Teste de login Superset OK
- [ ] Teste de login Airflow OK
- [ ] Cloudflare Tunnel atualizado
- [ ] Acessos externos funcionando
- [ ] Dashboards Superset preservados
- [ ] DAGs Airflow preservados
- [ ] Backups validados

---

## 🆘 Problemas Comuns

### OpenLDAP não inicia

```bash
# Verificar logs
docker logs openldap

# Erro comum: volume existente com dados incompatíveis
docker volume rm data-platform-ldap
docker compose up -d openldap
```

### Superset não conecta no LDAP

```bash
# Verificar rede
docker exec superset ping openldap

# Verificar variáveis de ambiente
docker exec superset env | grep LDAP

# Testar bind manualmente
docker exec superset python3 -c "
import ldap
conn = ldap.initialize('ldap://openldap:389')
conn.simple_bind_s('cn=admin,dc=bomgado,dc=local', 'senha')
print('OK')
"
```

### Usuários LDAP não aparecem no Superset/Airflow

- **Causa**: Grupos LDAP não mapeados corretamente
- **Solução**: Verificar `AUTH_ROLES_MAPPING` nos configs
- **Verificar**: Usuário está no grupo correto no LDAP

---

## 📞 Suporte

Problemas na migração? Consulte:
- [Troubleshooting](README.new.md#-troubleshooting)
- [Issues](https://github.com/CamilloBorges/superset_airflow_env/issues)
- Email: suporte@bomgado.com.br
