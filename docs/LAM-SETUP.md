# 🌟 LDAP Account Manager - Guia de Configuração

## 📋 Informações de Acesso

**URL:** http://48.217.81.171:8083 (ou https://lam.bomgado.com.br via Cloudflare)  
**Container:** ldap-account-manager  
**Porta:** 8083  
**Idioma:** Português (pt_BR)  

---

## 🔐 Primeiro Acesso

### 1. Acessar Interface Principal

1. Navegue até: http://48.217.81.171:8083
2. Você verá a **tela de configuração do LAM**

### 2. Configuração Inicial (Primeira Vez)

**⚠️ IMPORTANTE:** Na primeira vez, você precisa configurar o servidor LDAP.

1. Clique em **"LAM configuration"** (canto superior direito)
2. Clique em **"Edit server profiles"**
3. **Password master:** `lam` (senha padrão do LAM)
4. Clique em **"Ok"**

### 3. Configurar Perfil de Servidor

**General settings:**
```
Server address: ldap://openldap:389
Tree suffix: dc=bomgado,dc=local
```

**Security settings:**
```
List of valid users: cn=admin,dc=bomgado,dc=local
```

**Account types:**

| Tipo | Sufixo LDAP | Classes |
|------|-------------|---------|
| Users | `ou=users,dc=bomgado,dc=local` | inetOrgPerson, posixAccount |
| Groups | `ou=groups,dc=bomgado,dc=local` | groupOfNames |

**Clique em "Save" no final da página**

### 4. Login com Admin

1. Volte para tela inicial (clique no logo LAM)
2. **Username:** `admin`
3. **Password:** Senha do `.env` (LDAP_ADMIN_PASSWORD)
   - Exemplo: `otcW5KZIqluJVsvQzYTEk3EkEWRr9g3s`
4. Clique em **"Login"**

---

## 👤 Criar Novo Usuário via LAM

### Passo a Passo

1. **Login** no LAM (ver seção acima)

2. **Clique em "Users"** no menu superior

3. **Clique em "New user"** (botão superior direito)

4. **Preencha o formulário:**

   **Personal:**
   - First name: `João`
   - Last name: `Silva`
   - Common name: `João Silva` (auto-preenchido)

   **Unix:**
   - User name: `joao.silva` ← **Este é o login!**
   - UID number: (deixe auto-gerar)
   - Primary group: `10000` (ou selecione grupo)
   - Home directory: `/home/joao.silva`
   - Login shell: `/bin/bash`

   **Contact:**
   - Email address: `joao.silva@bomgado.com.br`

   **Password:**
   - Set password: ☑️ (marque checkbox)
   - Password: `senha_inicial_123`
   - Repeat password: `senha_inicial_123`

5. **Clique em "Save"** (final da página)

6. **Adicionar aos Grupos:**
   - Clique em **"Groups"** no menu superior
   - Selecione o grupo desejado (admins/analysts/viewers)
   - Clique em **"Edit"**
   - Na seção **"Group members"**, adicione: `cn=João Silva,ou=users,dc=bomgado,dc=local`
   - Clique em **"Save"**

---

## 🎯 Mapeamento de Grupos → Roles

| Grupo LDAP | Role Superset | Role Airflow | Permissões |
|------------|---------------|--------------|------------|
| **admins** | Admin | Admin | Administração completa |
| **analysts** | Alpha | Op, User | Criar/editar dashboards e workflows |
| **viewers** | Gamma | Viewer | Somente visualizar |

---

## 🔧 Configuração Avançada

### Alterar Senha Master do LAM

```bash
# SSH no servidor
ssh azureuser@48.217.81.171

# Acessar container
sudo docker exec -it ldap-account-manager /bin/bash

# Editar configuração
nano /var/lib/ldap-account-manager/config/lam.conf

# Alterar linha:
# passwd: {SSHA}... para nova senha hash
```

### Templates de Usuários

LAM suporta **templates** para criar usuários com configurações pré-definidas:

1. Login no LAM
2. **Tools** → **Account profiles**
3. Criar novo perfil com valores padrão
4. Ao criar usuário, selecionar template

---

## 🚀 Vantagens do LAM

✅ **Interface Simples:** Formulários intuitivos vs. árvore complexa do phpLDAPadmin  
✅ **Português:** Interface totalmente traduzida  
✅ **Templates:** Reutilizar configurações  
✅ **Validação:** Valida dados antes de salvar  
✅ **Self-Service:** Usuários podem trocar própria senha  
✅ **Import CSV:** Criar múltiplos usuários de uma vez  
✅ **Grupos Visual:** Gestão de grupos simplificada  

---

## 📚 Recursos

- **Documentação Oficial:** https://www.ldap-account-manager.org/lamcms/documentation
- **Docker Hub:** https://github.com/LDAPAccountManager/lam-docker
- **Suporte:** https://github.com/LDAPAccountManager/lam/issues

---

## 🆘 Troubleshooting

### Erro: "LDAP search failed"

**Causa:** Configuração incorreta do servidor LDAP

**Solução:**
1. Verifique que OpenLDAP está rodando: `sudo docker ps | grep openldap`
2. Verifique `Tree suffix` = `dc=bomgado,dc=local`
3. Verifique `Server address` = `ldap://openldap:389`

### Erro: "Invalid credentials"

**Causa:** Senha incorreta do admin LDAP

**Solução:**
1. Verifique senha no arquivo `.env`: `cat .env | grep LDAP_ADMIN_PASSWORD`
2. Use a senha exata (é case-sensitive)
3. **NÃO** use "admin123" - essa NÃO é a senha do LDAP!

### Container não inicia

**Verificar logs:**
```bash
sudo docker compose logs ldap-account-manager --tail=50
```

**Recriar volumes:**
```bash
sudo docker compose down
sudo docker volume rm data-platform-lam-config data-platform-lam-sessions
sudo docker compose up -d ldap-account-manager
```

---

## 📝 Comparação: LAM vs phpLDAPadmin vs Script

| Característica | LAM 🌟 | phpLDAPadmin | Script CLI |
|----------------|---------|--------------|------------|
| **Interface** | Formulários simples | Árvore LDAP complexa | Linha de comando |
| **Idioma** | Português | Inglês | Português |
| **Curva aprendizado** | Baixa | Alta | Média |
| **Templates** | ✅ Sim | ❌ Não | ❌ Não |
| **Self-service** | ✅ Sim | ❌ Não | ❌ Não |
| **Import CSV** | ✅ Sim | ❌ Não | ❌ Não |
| **Validação** | ✅ Automática | ⚠️ Manual | ⚠️ Manual |
| **Indicado para** | Gestores | Admins LDAP | Automação |

**Recomendação:** Use **LAM** para gestão web, **Script** para automação/integração.

---

**✨ Com o LAM, criar usuários LDAP é tão fácil quanto preencher um formulário web!**
