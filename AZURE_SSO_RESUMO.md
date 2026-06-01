# 🎯 Resumo Executivo - Azure Entra SSO

## ✅ O Que Foi Criado

Documentação completa para habilitar **Single Sign-On (SSO)** com **Azure Entra ID** (antigo Azure AD) para sua plataforma de dados.

---

## 📚 Arquivos Criados

| Arquivo | Descrição |
|---------|-----------|
| **AZURE_ENTRA_SSO.md** | Guia completo passo-a-passo de configuração SSO |
| **superset/config/superset_config_azure.py.example** | Template de configuração OAuth para Superset |
| **airflow/config/webserver_config.py.example** | Template de configuração OAuth para Airflow |
| **configure-azure-sso.sh** | Script automatizado de configuração |
| **.env.example** | Atualizado com variáveis Azure SSO |

---

## 🚀 Como Habilitar SSO (Resumo de 5 Passos)

### 1️⃣ Criar App Registrations no Azure Portal

Acesse [Azure Portal](https://portal.azure.com) → **Microsoft Entra ID** → **App registrations** → **+ New registration**

Crie **2 aplicações:**

**App 1: Apache Superset SSO**
```
Name: Apache Superset SSO
Redirect URI: https://172.174.210.23:8088/oauth-authorized/azure
```

**App 2: Apache Airflow SSO**
```
Name: Apache Airflow SSO
Redirect URI: https://172.174.210.23:8080/oauth-authorized/azure
```

> ⚠️ **IMPORTANTE:** Azure Entra ID **exige HTTPS**. Configure SSL/TLS antes (veja AZURE_ENTRA_SSO.md seção "Passo 0").

Para cada App:
- Anote o **Application (client) ID**
- Crie um **Client Secret** em **Certificates & secrets**
- Anote o **Directory (tenant) ID**
- Configure **API Permissions**: `User.Read`, `email`, `openid`, `profile`
- Conceda **Admin consent**

---

### 2️⃣ Configurar Variáveis no .env

Adicione ao arquivo `.env`:

```bash
# Azure Entra ID SSO
AZURE_TENANT_ID=seu-tenant-id-aqui
AZURE_SUPERSET_CLIENT_ID=client-id-do-superset
AZURE_SUPERSET_CLIENT_SECRET=client-secret-do-superset
AZURE_AIRFLOW_CLIENT_ID=client-id-do-airflow
AZURE_AIRFLOW_CLIENT_SECRET=client-secret-do-airflow
```

---

### 3️⃣ Criar Arquivos de Configuração

**Opção A: Script Automatizado (Recomendado)**
```bash
chmod +x configure-azure-sso.sh
./configure-azure-sso.sh
```

**Opção B: Manual**

Copie os templates:
```bash
cp superset/config/superset_config_azure.py.example superset/config/superset_config_azure.py
cp airflow/config/webserver_config.py.example airflow/config/webserver_config.py
```

Edite os arquivos substituindo `YOUR_*_HERE` pelos valores reais.

---

### 4️⃣ Atualizar docker-compose.yml

Adicione os volumes de configuração:

**Para Superset:**
```yaml
superset:
  environment:
    - SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config_azure.py
  volumes:
    - ./superset/config:/app/pythonpath
```

**Para Airflow:**
```yaml
x-airflow-common:
  volumes:
    - ./airflow/config:/opt/airflow/config

airflow-webserver:
  environment:
    - AIRFLOW__WEBSERVER__CONFIG_FILE=/opt/airflow/config/webserver_config.py
```

---

### 5️⃣ Reiniciar Containers

```bash
docker compose restart superset superset-worker superset-beat
docker compose restart airflow-webserver airflow-scheduler

# Aguardar 30-60 segundos

# Verificar logs
docker compose logs -f superset | grep -i oauth
docker compose logs -f airflow-webserver | grep -i oauth
```

---

## 🎯 Testar SSO

1. **Superset:** Acesse http://172.174.210.23:8088
2. Clique em **"Sign in with Azure"** (botão com ícone Windows)
3. Faça login com credenciais Microsoft
4. Será redirecionado de volta logado

Repita para **Airflow** em https://172.174.210.23:8080

---

## ✨ Benefícios

- ✅ **Login único** - Um login para Superset e Airflow
- ✅ **Gerenciamento centralizado** - Usuários controlados no Azure AD
- ✅ **MFA nativo** - Autenticação multifator automática
- ✅ **Sem senhas locais** - Não precisa gerenciar senhas separadas
- ✅ **Auditoria** - Logs centralizados no Azure
- ✅ **Grupos/Roles** - Mapear grupos do Azure para permissões

---

## 🔍 Verificar se Funcionou

```bash
# Ver usuários criados no Superset
docker compose exec superset superset fab list-users

# Ver usuários criados no Airflow
docker compose exec airflow-webserver airflow users list
```

Você deve ver usuários com email do Azure AD.

---

## 🛡️ Segurança em Produção

Para produção, **configure HTTPS:**

1. Use certificado SSL/TLS (Let's Encrypt ou corporativo)
2. Atualize Redirect URIs no Azure para `https://`
3. Configure reverse proxy (Nginx/Caddy)
4. Restrinja acesso por IP no Azure NSG

---

## 📖 Documentação Completa

Consulte **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** para:
- Configuração avançada de grupos/roles
- Troubleshooting detalhado
- Mapeamento de grupos do Azure AD
- Configuração SAML (alternativa ao OAuth)
- Logs e diagnósticos

---

## 🆘 Troubleshooting Rápido

### Botão "Sign in with Azure" não aparece
```bash
# Verificar se config foi carregada
docker compose exec superset ls -la /app/pythonpath/
docker compose logs superset | grep -i config
```

### Erro "Redirect URI mismatch"
- Verifique se URI no Azure é exatamente:
  - `https://172.174.210.23:8088/oauth-authorized/azure` (Superset)
  - `https://172.174.210.23:8080/oauth-authorized/azure` (Airflow)
- Sem `/` no final
- **DEVE usar HTTPS** (Azure Entra ID exige)

### Erro "Invalid client secret"
- Client Secret expirou? Crie um novo no Azure Portal
- Copie o **Value** (não o Secret ID)
- Atualize `.env` e reinicie containers

---

## 📊 Arquitetura SSO

```
┌─────────────┐
│   Usuário   │
└──────┬──────┘
       │ 1. Acessa Superset/Airflow
       ▼
┌─────────────────────┐
│ Superset/Airflow    │──┐
│ (Service Provider)  │  │ 2. Redireciona
└─────────────────────┘  │
                         ▼
                  ┌──────────────┐
                  │ Azure Entra  │
                  │ (IdP OAuth)  │
                  └──────┬───────┘
                         │ 3. Login Microsoft
                         │ 4. Token OAuth
                         ▼
                  ┌──────────────┐
                  │   Valida     │
                  │   Token      │
                  └──────┬───────┘
                         │ 5. Cria usuário
                         │ 6. Sessão ativa
                         ▼
                  ┌──────────────┐
                  │   Dashboard  │
                  │   (Logado)   │
                  └──────────────┘
```

---

## ✅ Checklist de Implementação

- [ ] Criados 2 App Registrations no Azure
- [ ] Client IDs e Secrets copiados
- [ ] Tenant ID identificado
- [ ] API Permissions configuradas
- [ ] Admin consent concedido
- [ ] Redirect URIs configurados
- [ ] Variáveis adicionadas ao `.env`
- [ ] Arquivos de config criados
- [ ] `docker-compose.yml` atualizado
- [ ] Containers reiniciados
- [ ] Logs verificados (sem erros)
- [ ] Login SSO testado no Superset
- [ ] Login SSO testado no Airflow
- [ ] Usuários criados verificados

---

## 🎓 Próximos Passos

1. **Mapear grupos do Azure AD** para roles específicas
2. **Configurar HTTPS** para produção
3. **Desabilitar login local** (forçar SSO)
4. **Implementar logout único** (Single Logout)
5. **Adicionar MFA obrigatório** no Azure

---

**SSO Pronto para Configurar!** 🚀  

Siga o guia completo em [AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md) ou execute `./configure-azure-sso.sh` para configuração automatizada.
