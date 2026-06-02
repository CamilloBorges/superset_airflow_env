# 🔧 Troubleshooting: Azure Entra SSO

## 🎯 Problema Identificado

**Sintomas:**
- Login via Azure Entra funciona (redirecionamento OK)
- Mas usuários **NÃO são criados automaticamente**
- `superset fab list-users` e `airflow users list` mostram apenas usuário admin padrão

**Causa Raiz:**
Os arquivos de configuração OAuth **não estão sendo carregados** pelos containers.

---

## ✅ Solução Completa

### Passo 1: Verificar Arquivos de Configuração no Servidor

SSH no servidor:
```bash
ssh -i C:\Users\camil\.ssh\bomgado.bi.pem azureuser@48.217.186.142
cd /home/azureuser/superset_airflow_env
```

**Verificar se os arquivos existem:**
```bash
# Airflow
ls -la airflow/config/

# Superset
ls -la superset/config/
```

**Você deve ter:**
- `airflow/config/webserver_config.py` (NÃO .example)
- `superset/config/superset_config.py` (NÃO .example)

---

### Passo 2: Criar/Atualizar Arquivos de Configuração

#### 📝 Airflow: `/home/azureuser/superset_airflow_env/airflow/config/webserver_config.py`

```bash
cat > airflow/config/webserver_config.py << 'EOF'
# webserver_config.py - Azure Entra ID OAuth Configuration for Airflow

from flask_appbuilder.security.manager import AUTH_OAUTH
import os

# --------------------------------------------------
# Azure Entra ID OAuth Configuration
# --------------------------------------------------

AUTH_TYPE = AUTH_OAUTH

OAUTH_PROVIDERS = [
    {
        'name': 'azure',
        'icon': 'fa-windows',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.getenv('AZURE_AIRFLOW_CLIENT_ID'),
            'client_secret': os.getenv('AZURE_AIRFLOW_CLIENT_SECRET'),
            'api_base_url': 'https://graph.microsoft.com/v1.0/',
            'client_kwargs': {
                'scope': 'openid email profile User.Read'
            },
            'access_token_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token",
            'authorize_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/authorize",
            'server_metadata_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/v2.0/.well-known/openid-configuration",
        }
    }
]

# Auto-registrar usuários no primeiro login
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"

# Implementar Security Manager customizado
from airflow.www.security import AirflowSecurityManager

class AzureSecurityManager(AirflowSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'azure':
            import requests
            access_token = response.get('access_token')
            
            me = requests.get(
                'https://graph.microsoft.com/v1.0/me',
                headers={'Authorization': f'Bearer {access_token}'}
            ).json()
            
            return {
                'username': me.get('userPrincipalName', '').split('@')[0],
                'name': me.get('displayName', ''),
                'email': me.get('mail') or me.get('userPrincipalName'),
                'first_name': me.get('givenName', ''),
                'last_name': me.get('surname', ''),
                'role_keys': ['Viewer'],
            }
        return {}

SECURITY_MANAGER_CLASS = AzureSecurityManager
EOF
```

#### 📝 Superset: `/home/azureuser/superset_airflow_env/superset/config/superset_config.py`

```bash
cat > superset/config/superset_config.py << 'EOF'
# superset_config.py - Azure Entra ID OAuth Configuration

from flask_appbuilder.security.manager import AUTH_OAUTH
import os

# --------------------------------------------------
# Azure Entra ID OAuth Configuration
# --------------------------------------------------

AUTH_TYPE = AUTH_OAUTH

OAUTH_PROVIDERS = [
    {
        'name': 'azure',
        'icon': 'fa-windows',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.getenv('AZURE_SUPERSET_CLIENT_ID'),
            'client_secret': os.getenv('AZURE_SUPERSET_CLIENT_SECRET'),
            'api_base_url': 'https://graph.microsoft.com/v1.0/',
            'client_kwargs': {
                'scope': 'openid email profile User.Read'
            },
            'access_token_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/token",
            'authorize_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/oauth2/v2.0/authorize",
            'server_metadata_url': f"https://login.microsoftonline.com/{os.getenv('AZURE_TENANT_ID')}/v2.0/.well-known/openid-configuration",
        }
    }
]

# Auto-registrar usuários
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"

# Security Manager customizado
from superset.security import SupersetSecurityManager

class AzureSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'azure':
            import requests
            access_token = response.get('access_token')
            
            me = requests.get(
                'https://graph.microsoft.com/v1.0/me',
                headers={'Authorization': f'Bearer {access_token}'}
            ).json()
            
            return {
                'username': me.get('userPrincipalName', '').split('@')[0],
                'name': me.get('displayName', ''),
                'email': me.get('mail') or me.get('userPrincipalName'),
                'first_name': me.get('givenName', ''),
                'last_name': me.get('surname', ''),
            }
        return {}

CUSTOM_SECURITY_MANAGER = AzureSecurityManager
EOF
```

---

### Passo 3: Atualizar docker-compose.yml

**Adicionar variáveis de ambiente para carregar os arquivos de configuração:**

```bash
nano docker-compose.yml
```

**No serviço `airflow-webserver` (e demais serviços airflow), adicionar ao `environment`:**

```yaml
# Procure a seção x-airflow-common e adicione ao environment:
x-airflow-common: &airflow-common
  image: apache/airflow:2.8.0-python3.11
  environment:
    &airflow-common-env
    # ... outras variáveis existentes ...
    AIRFLOW__WEBSERVER__CONFIG_FILE: /opt/airflow/config/webserver_config.py
    AZURE_AIRFLOW_CLIENT_ID: ${AZURE_AIRFLOW_CLIENT_ID}
    AZURE_AIRFLOW_CLIENT_SECRET: ${AZURE_AIRFLOW_CLIENT_SECRET}
    AZURE_TENANT_ID: ${AZURE_TENANT_ID}
```

**Nos serviços Superset (`superset`, `superset-worker`, `superset-beat`), adicionar:**

```yaml
superset:
  image: apache/superset:3.0.0
  container_name: superset
  environment:
    # ... outras variáveis existentes ...
    SUPERSET_CONFIG_PATH: /app/superset_home/superset_config.py
    AZURE_SUPERSET_CLIENT_ID: ${AZURE_SUPERSET_CLIENT_ID}
    AZURE_SUPERSET_CLIENT_SECRET: ${AZURE_SUPERSET_CLIENT_SECRET}
    AZURE_TENANT_ID: ${AZURE_TENANT_ID}
```

---

### Passo 4: Atualizar .env com Credenciais Azure

```bash
nano .env
```

**Adicionar (com seus valores reais):**

```bash
# Azure Entra ID SSO
AZURE_TENANT_ID=seu-tenant-id-aqui

# Airflow App Registration
AZURE_AIRFLOW_CLIENT_ID=seu-airflow-client-id-aqui
AZURE_AIRFLOW_CLIENT_SECRET=seu-airflow-client-secret-aqui

# Superset App Registration (use os valores do seu App Registration do Superset)
AZURE_SUPERSET_CLIENT_ID=seu-superset-client-id-aqui
AZURE_SUPERSET_CLIENT_SECRET=seu-superset-client-secret-aqui
```

---

### Passo 5: Reiniciar Containers

```bash
# Parar todos os containers
docker compose down

# Iniciar novamente
docker compose up -d

# Aguardar 1-2 minutos

# Verificar logs
docker compose logs -f superset airflow-webserver
```

---

### Passo 6: Testar SSO

#### Teste 1: Verificar se arquivo foi carregado

```bash
# Airflow - verificar se webserver_config.py está sendo usado
docker compose exec airflow-webserver cat /opt/airflow/config/webserver_config.py | head -20

# Superset - verificar se superset_config.py está sendo usado
docker compose exec superset cat /app/superset_home/superset_config.py | head -20
```

#### Teste 2: Login via Azure Entra

1. **Superset:** https://bi.bomgado.com.br
   - Clique em "Sign in with azure"
   - Faça login com conta Microsoft
   
2. **Airflow:** https://airflow.bomgado.com.br
   - Clique em "Sign in with azure"
   - Faça login com conta Microsoft

#### Teste 3: Verificar se usuário foi criado

```bash
# Superset
docker compose exec superset superset fab list-users

# Airflow
docker compose exec airflow-webserver airflow users list
```

**Resultado esperado:**
```
# Superset
id | username      | email                  | first_name | last_name
===+===============+========================+============+==========
1  | admin         | admin@localhost        | Admin      | User
2  | camil.santos  | camil@bomgado.com.br   | Camil      | Santos

# Airflow
id | username     | email                 | first_name | last_name | roles
===+==============+=======================+============+===========+=======
1  | admin        | admin@...             | Admin      | User      | Admin
2  | camil.santos | camil@bomgado.com.br  | Camil      | Santos    | Viewer
```

---

## 🔍 Troubleshooting Adicional

### Erro: "OAuth provider not configured"

**Verificar:**
```bash
# Variáveis chegando no container?
docker compose exec airflow-webserver env | grep AZURE
docker compose exec superset env | grep AZURE
```

### Erro: "Unable to get user info"

**Verificar logs detalhados:**
```bash
# Airflow
docker compose logs airflow-webserver | grep -i oauth

# Superset
docker compose logs superset | grep -i oauth
```

### Usuário não criado após login

**Verificar:**
1. `AUTH_USER_REGISTRATION = True` está configurado?
2. Redirect URI está correto no Azure Portal?
3. Permissões da API estão concedidas? (User.Read)

---

## 📝 Checklist Completo

- [ ] Arquivo `airflow/config/webserver_config.py` criado
- [ ] Arquivo `superset/config/superset_config.py` criado
- [ ] `docker-compose.yml` atualizado com variáveis de ambiente
- [ ] `.env` atualizado com credenciais Azure
- [ ] Containers reiniciados (`docker compose down && docker compose up -d`)
- [ ] Login via Azure Entra testado
- [ ] Usuários criados automaticamente verificados

---

## 🆘 Se Ainda Não Funcionar

**Executar diagnóstico completo:**

```bash
# 1. Verificar se arquivos existem
ls -la airflow/config/webserver_config.py
ls -la superset/config/superset_config.py

# 2. Verificar se volumes estão montados
docker compose exec airflow-webserver ls -la /opt/airflow/config/
docker compose exec superset ls -la /app/superset_home/

# 3. Verificar variáveis de ambiente
docker compose exec airflow-webserver env | grep -E "(AZURE|AIRFLOW__WEBSERVER__CONFIG)"
docker compose exec superset env | grep -E "(AZURE|SUPERSET_CONFIG)"

# 4. Logs detalhados
docker compose logs --tail=100 airflow-webserver
docker compose logs --tail=100 superset
```

**Envie a saída desses comandos para análise.**
