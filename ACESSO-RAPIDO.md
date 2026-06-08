# 🚀 Guia de Acesso Rápido - Plataforma de Dados

## 🌐 URLs de Acesso (via Cloudflare Tunnel)

| Aplicação | URL HTTPS | URL Local |
|-----------|-----------|-----------|
| **Superset** | https://bi.bomgado.com.br | http://48.217.81.171:8088 |
| **Airflow** | https://airflow.bomgado.com.br | http://48.217.81.171:8080 |
| **Apache Hop** | https://hop.bomgado.com.br | http://48.217.81.171:8081 |
| **LDAP Account Manager** 🌟 | https://lam.bomgado.com.br | http://48.217.81.171:8083 |
| **phpLDAPadmin** | https://ldap.bomgado.com.br | http://48.217.81.171:8082 |

---

## 🔐 Credenciais de Acesso

### Superset (BI/Analytics)
```
URL: https://bi.bomgado.com.br
Usuário: admin
Senha: admin123
⚠️  TROQUE após primeiro login!
```

### Airflow (Workflows)
```
URL: https://airflow.bomgado.com.br
Usuário: admin
Senha: admin123
⚠️  TROQUE após primeiro login!
```

### LDAP Account Manager 🌟 (Gestão Simplificada de Usuários)
```
URL: https://lam.bomgado.com.br
Usuário: cn=admin,dc=bomgado,dc=local
Senha: otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s

✅ INTERFACE SIMPLIFICADA:
• Formulários intuitivos para criar usuários
• Templates pré-configurados
• Importação CSV em massa
• Interface em Português
• MUITO mais fácil que phpLDAPadmin!
```

### phpLDAPadmin (Gerenciamento LDAP Avançado)
```
URL: https://ldap.bomgado.com.br
Login DN: cn=admin,dc=bomgado,dc=local
Senha: otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s

⚠️  IMPORTANTE:
• NÃO use "admin123" - esta senha NÃO funciona!
• Use a senha LDAP_ADMIN_PASSWORD do arquivo .env ou .credentials-*.txt
• Acesso anônimo está DESABILITADO por segurança
• Use LAM (acima) para gestão simplificada!
```

### Apache Hop (ETL)
```
URL: https://hop.bomgado.com.br
Configuração: Via interface web
```

---

## 📋 Estrutura LDAP

### Base DN
```
dc=bomgado,dc=local
```

### Unidades Organizacionais (OUs)
```
ou=users,dc=bomgado,dc=local     → Usuários da plataforma
ou=groups,dc=bomgado,dc=local    → Grupos de segurança
ou=services,dc=bomgado,dc=local  → Contas de serviço
```

### Grupos de Segurança

| Grupo LDAP | Role Superset | Role Airflow | Descrição |
|------------|---------------|--------------|-----------|
| `cn=admins,ou=groups,dc=bomgado,dc=local` | Admin | Admin | Administração completa |
| `cn=analysts,ou=groups,dc=bomgado,dc=local` | Alpha | Op, User | Criação/edição de dashboards |
| `cn=viewers,ou=groups,dc=bomgado,dc=local` | Gamma | Viewer | Somente leitura |

---

## 🆕 Como Criar Novo Usuário LDAP

### 🌐 Método 1: LDAP Account Manager (Interface Web - Mais Fácil!) 🌟

1. Acesse: **https://lam.bomgado.com.br**
2. Login: `cn=admin,dc=bomgado,dc=local`
3. Senha: do arquivo `.env` (LDAP_ADMIN_PASSWORD)
4. Clique em **"Users"** → **"New user"**
5. Preencha o formulário:
   - Nome completo
   - Username (uid)
   - Email
   - Senha
   - Selecione grupo: admins/analysts/viewers
6. Salve

**✅ Interface em Português, formulários simples, templates prontos!**

---

### ⚡ Método 2: Script Automatizado (Linha de Comando)

**SSH no servidor e execute:**
```bash
cd ~/data-platform
make user
```

O script interativo pergunta:
- Nome completo
- Username
- Email
- Senha (com confirmação)
- Grupo (Admin/Analista/Visualizador)

**Pronto!** O usuário é criado automaticamente com todas as configurações necessárias.

**Outros comandos úteis:**
```bash
make list-users         # Lista todos os usuários
make list-groups        # Lista grupos e membros  
make delete-user        # Remove um usuário
make test-user-login    # Testa credenciais
```

---

### Via phpLDAPadmin (Interface Web)

1. **Acesse:** https://ldap.bomgado.com.br
2. **Login:**
   - DN: `cn=admin,dc=bomgado,dc=local`
   - Password: `otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s`
3. **Navegar:** Clique em `ou=users,dc=bomgado,dc=local`
4. **Criar:** Create new entry → inetOrgPerson
5. **Preencher:**
   ```
   cn: João Silva
   sn: Silva
   givenName: João
   uid: joao.silva
   mail: joao.silva@bomgado.local
   userPassword: ******** (será criptografada)
   ```
6. **Adicionar ao grupo:**
   - Navegue até `cn=admins,ou=groups,dc=bomgado,dc=local`
   - Add new attribute → member
   - Value: `cn=João Silva,ou=users,dc=bomgado,dc=local`

### Via Linha de Comando (SSH no servidor)

```bash
# 1. Criar arquivo com dados do usuário
cat > user.ldif <<EOF
dn: cn=João Silva,ou=users,dc=bomgado,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: João Silva
sn: Silva
givenName: João
uid: joao.silva
uidNumber: 10001
gidNumber: 10000
homeDirectory: /home/joao.silva
loginShell: /bin/bash
mail: joao.silva@bomgado.local
userPassword: senha_temporaria_123
EOF

# 2. Adicionar usuário ao LDAP
docker exec openldap ldapadd -x -H ldap://localhost:389 \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s" \
  -f /tmp/user.ldif

# 3. Adicionar usuário ao grupo admins
cat > add_to_group.ldif <<EOF
dn: cn=admins,ou=groups,dc=bomgado,dc=local
changetype: modify
add: member
member: cn=João Silva,ou=users,dc=bomgado,dc=local
EOF

docker exec openldap ldapmodify -x -H ldap://localhost:389 \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s" \
  -f /tmp/add_to_group.ldif
```

---

## 🔍 Testar Autenticação LDAP

### Verificar se usuário existe
```bash
docker exec openldap ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s" \
  -b "ou=users,dc=bomgado,dc=local" \
  "(uid=joao.silva)"
```

### Testar login do usuário
```bash
docker exec openldap ldapwhoami -x -H ldap://localhost:389 \
  -D "cn=João Silva,ou=users,dc=bomgado,dc=local" \
  -w "senha_do_usuario"
```

### Verificar grupos do usuário
```bash
docker exec openldap ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s" \
  -b "ou=groups,dc=bomgado,dc=local" \
  "(member=cn=João Silva,ou=users,dc=bomgado,dc=local)"
```

---

## 🔧 Comandos Úteis

### Verificar status dos containers
```bash
cd ~/data-platform
docker compose ps
```

### Ver logs de um serviço
```bash
docker compose logs -f superset        # Logs Superset em tempo real
docker compose logs -f airflow-webserver
docker compose logs -f openldap
```

### Reiniciar um serviço
```bash
docker compose restart superset
docker compose restart airflow-webserver
docker compose restart openldap
```

### Reiniciar toda a plataforma
```bash
docker compose down
docker compose up -d
```

### Backup do LDAP
```bash
# Exportar todos os dados do LDAP
docker exec openldap slapcat -v -l /tmp/ldap-backup.ldif
docker cp openldap:/tmp/ldap-backup.ldif ./ldap-backup-$(date +%Y%m%d).ldif
```

---

## 🆘 Troubleshooting

### Erro "Invalid credentials" no phpLDAPadmin
```
Problema: Senha incorreta
Solução: Use LDAP_ADMIN_PASSWORD do arquivo .env ou .credentials-*.txt
         NÃO use "admin123"!
```

### Erro "Anonymous bind disallowed"
```
Problema: Tentando acessar sem autenticação
Solução: Acesso anônimo foi DESABILITADO por segurança
         Sempre forneça credenciais (DN + senha)
```

### Container unhealthy
```bash
# Ver logs do container
docker compose logs <nome-container>

# Reiniciar container específico
docker compose restart <nome-container>
```

### Trocar senha do LDAP Admin
```bash
# 1. Editar .env
nano .env
# Altere: LDAP_ADMIN_PASSWORD=nova_senha_forte_aqui

# 2. Recriar containers (CUIDADO: apaga dados!)
docker compose down -v
docker compose up -d
```

---

## 📞 Suporte

**Servidor:** 48.217.81.171  
**SSH:** `ssh -i ~/.ssh/bomgado.bi_key.pem azureuser@48.217.81.171`  
**Diretório:** `~/data-platform`  

**Arquivos Importantes:**
- `.env` - Variáveis de ambiente e senhas
- `.credentials-*.txt` - Credenciais geradas na instalação
- `docker-compose.yml` - Configuração dos containers
- `README.md` - Documentação completa
