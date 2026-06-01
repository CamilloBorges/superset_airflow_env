# 🔐 Guia de Configuração - Azure Entra ID SSO

Este guia configura **Single Sign-On (SSO)** com **Azure Entra ID** (antigo Azure AD) para **Apache Superset** e **Apache Airflow**.

---

## 📋 Índice

1. [Visão Geral](#-visão-geral)
2. [Pré-requisitos](#-pré-requisitos)
3. [Configurar Azure Entra ID](#-parte-1-configurar-azure-entra-id)
4. [Configurar Superset com OAuth2](#-parte-2-configurar-superset-com-oauth2)
5. [Configurar Airflow com OAuth2](#-parte-3-configurar-airflow-com-oauth2)
6. [Testar SSO](#-parte-4-testar-sso)
7. [Troubleshooting](#-troubleshooting)

---

## 🎯 Visão Geral

### O que será configurado?

- **Azure Entra ID** como Identity Provider (IdP)
- **Apache Superset** usando OAuth2/OpenID Connect
- **Apache Airflow** usando OAuth2/OpenID Connect
- SSO unificado: login único para ambas plataformas

### Fluxo de Autenticação

```
Usuário → Superset/Airflow → Azure Entra ID → Login Microsoft → Token → Acesso Concedido
```

### Benefícios

✅ Login único (SSO) para Superset e Airflow  
✅ Gerenciamento centralizado de usuários no Azure  
✅ Autenticação multifator (MFA) nativa do Azure  
✅ Integração com grupos do Azure AD  
✅ Auditoria e logs centralizados  
✅ Não precisa gerenciar senhas separadas

---

## 📋 Pré-requisitos

- [ ] Conta Azure com permissões de **Application Administrator** ou **Cloud Application Administrator**
- [ ] Acesso ao [Azure Portal](https://portal.azure.com)
- [ ] Ambiente rodando (Superset e Airflow com containers up)
- [ ] **Cloudflare Tunnel configurado** (recomendado) OU **HTTPS configurado**
- [ ] **Domínio público configurado:** `bi.bomgado.com.br`

---

## 🔒 Passo 0: Verificar HTTPS

**Azure Entra ID exige HTTPS para redirect URIs.** 

### Com Cloudflare Tunnel (Recomendado)

✅ **HTTPS já está configurado automaticamente!**

Cloudflare gerencia SSL/TLS. Nenhuma configuração adicional necessária.

> 📖 Guia: [CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)

### Sem Cloudflare Tunnel

Se não usar Cloudflare Tunnel, você precisa configurar HTTPS manualmente:

```bash
# Gera certificado auto-assinado (desenvolvimento)
./generate-ssl-cert.sh

# OU Let's Encrypt (produção)
./generate-letsencrypt-cert.sh
```

> 📖 Guia: [HTTPS_SETUP.md](HTTPS_SETUP.md)

```bash
# Configure PUBLIC_DOMAIN no .env primeiro
nano .env
# PUBLIC_DOMAIN=dados.suaempresa.com

# Gera certificado Let's Encrypt
./generate-letsencrypt-cert.sh
```

> 📖 **Guia completo de HTTPS:** [HTTPS_SETUP.md](HTTPS_SETUP.md)

### Verificar HTTPS Funcionando

```bash
# Com Cloudflare Tunnel
curl https://bi.bomgado.com.br
curl https://airflow.bomgado.com.br

# Ou localmente
curl http://localhost
curl http://localhost:8080

Adicione ao `docker-compose.yml`:

```yaml
nginx:
  image: nginx:alpine
  container_name: nginx-proxy
  ports:
    - "443:443"
    - "80:80"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./certs:/etc/nginx/certs:ro
  depends_on:
    - superset
    - airflow-webserver
  networks:
    - data-platform-network
```

### Opção 4: Azure Application Gateway com SSL (Produção Enterprise)

Para ambientes enterprise, use **Azure Application Gateway** com:
- Certificado gerenciado pelo Azure
- WAF (Web Application Firewall)
- SSL/TLS offloading

Consulte: https://learn.microsoft.com/azure/application-gateway/

### Testar HTTPS

```bash
# Após configurar SSL
curl -k https://172.174.210.23:8088/health  # Superset
curl -k https://172.174.210.23:8080/health  # Airflow

# Flag -k ignora certificado auto-assinado
```

---

## 🌩️ Parte 1: Configurar Azure Entra ID

### Passo 1.1: Criar App Registration para Superset

1. Acesse o [Azure Portal](https://portal.azure.com)
2. Navegue até: **Microsoft Entra ID** (ou Azure Active Directory)
3. Menu lateral: **App registrations** → **+ New registration**

4. **Configurações do App:**
   ```
   Name: Apache Superset SSO
   Supported account types: Accounts in this organizational directory only
   Redirect URI:
     Platform: Web
     Redirect URI: https://bi.bomgado.com.br/oauth-authorized/azure
   ```
   
   > ⚠️ **IMPORTANTE:** Azure Entra ID **exige HTTPS** para redirect URIs. Configure SSL antes (veja seção abaixo).

5. Clique em **Register**

### Passo 1.2: Configurar Client Secret (Superset)

1. No App criado, menu lateral: **Certificates & secrets**
2. Clique em **+ New client secret**
3. Configure:
   ```
   Description: Superset OAuth Secret
   Expires: 24 months (ou conforme política da empresa)
   ```
4. Clique em **Add**
5. **COPIE O VALUE IMEDIATAMENTE** (não será mostrado novamente)
   ```
   Exemplo: abc123~XyZ456.qwerty789-AbCdEf
   ```

### Passo 1.3: Obter Application (client) ID e Tenant ID

1. Ainda no App, vá em **Overview**
2. **Copie os valores:**
   ```
   Application (client) ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   Directory (tenant) ID:   yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
   ```

### Passo 1.4: Configurar API Permissions

1. Menu lateral: **API permissions**
2. Clique em **+ Add a permission**
3. Selecione **Microsoft Graph**
4. Selecione **Delegated permissions**
5. Adicione as permissões:
   - ✅ `User.Read` (Read user profile)
   - ✅ `email`
   - ✅ `openid`
   - ✅ `profile`
6. Clique em **Add permissions**
7. Clique em **Grant admin consent for [Sua Organização]** → **Yes**

### Passo 1.5: Repetir para Airflow

Repita os **passos 1.1 a 1.4**, mas com estas diferenças:

```
Name: Apache Airflow SSO
Redirect URI: https://airflow.bomgado.com.br/oauth-authorized/azure
```

Agora você terá:
- **2 App Registrations** (Superset e Airflow)
- **2 Client IDs**
- **2 Client Secrets**
- **1 Tenant ID** (mesmo para ambos)

---

## 🎨 Parte 2: Configurar Superset com OAuth2

### Passo 2.1: Criar Arquivo de Configuração

Crie o arquivo `superset/config/superset_config_azure.py`:

```bash
# No servidor Azure
cd ~/superset_airflow_env
mkdir -p superset/config
nano superset/config/superset_config_azure.py
```

### Passo 2.2: Adicionar Configuração OAuth

Cole o seguinte conteúdo (substitua os valores):

```python
# superset_config_azure.py - Azure Entra ID OAuth Configuration

from flask_appbuilder.security.manager import AUTH_OAUTH
import os

# --------------------------------------------------
# Azure Entra ID OAuth Configuration
# --------------------------------------------------

# Tipo de autenticação
AUTH_TYPE = AUTH_OAUTH

# Configuração do OAuth
OAUTH_PROVIDERS = [
    {
        'name': 'azure',
        'icon': 'fa-windows',  # Ícone do botão de login
        'token_key': 'access_token',
        'remote_app': {
            'client_id': 'SEU_SUPERSET_CLIENT_ID_AQUI',  # Application (client) ID
            'client_secret': 'SEU_SUPERSET_CLIENT_SECRET_AQUI',  # Client Secret Value
            'api_base_url': 'https://graph.microsoft.com/v1.0/',
            'client_kwargs': {
                'scope': 'openid email profile User.Read'
            },
            'access_token_url': 'https://login.microsoftonline.com/SEU_TENANT_ID_AQUI/oauth2/v2.0/token',
            'authorize_url': 'https://login.microsoftonline.com/SEU_TENANT_ID_AQUI/oauth2/v2.0/authorize',
            'server_metadata_url': 'https://login.microsoftonline.com/SEU_TENANT_ID_AQUI/v2.0/.well-known/openid-configuration',
        }
    }
]

# Mapeamento de informações do usuário
AUTH_USER_REGISTRATION = True  # Auto-registrar novos usuários
AUTH_USER_REGISTRATION_ROLE = "Public"  # Papel padrão para novos usuários

# Mapear campos do Azure AD para o Superset
def get_oauth_user_info(provider, response):
    """
    Extrai informações do usuário do Azure AD
    """
    if provider == 'azure':
        # Obter dados do Microsoft Graph
        me = response.get('userinfo')
        if not me:
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

# Importar a função
from superset.security import SupersetSecurityManager

class AzureSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        return get_oauth_user_info(provider, response)

CUSTOM_SECURITY_MANAGER = AzureSecurityManager

# --------------------------------------------------
# Configurações Adicionais
# --------------------------------------------------

# URL pública do Superset
PUBLIC_ROLE_LIKE = "Gamma"  # Permissões básicas para usuários SSO

# Roles automáticos baseados em grupos do Azure AD (Opcional)
# AUTH_ROLES_MAPPING = {
#     "Superset-Admins": ["Admin"],
#     "Superset-Users": ["Gamma"],
# }

# Sincronizar roles com grupos do Azure AD
# AUTH_ROLES_SYNC_AT_LOGIN = True

# Log de debug (remover em produção)
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Passo 2.3: Substituir Valores

Edite o arquivo e substitua:

```python
client_id': 'SEU_SUPERSET_CLIENT_ID_AQUI'
client_secret': 'SEU_SUPERSET_CLIENT_SECRET_AQUI'
SEU_TENANT_ID_AQUI  # Aparece 3 vezes
```

Exemplo real:
```python
client_id': '12345678-1234-1234-1234-123456789abc'
client_secret': 'abc123~XyZ456.qwerty789'
'https://login.microsoftonline.com/abcd1234-5678-90ab-cdef-1234567890ab/oauth2/v2.0/token'
```

### Passo 2.4: Atualizar docker-compose.yml

Edite o serviço `superset` no `docker-compose.yml`:

```yaml
superset:
  image: apache/superset:3.0.0
  container_name: superset
  environment:
    - SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config_azure.py  # Adicionar esta linha
  volumes:
    - ./superset/config:/app/pythonpath  # Mapear diretório de config
    - ./superset/data:/app/superset_home
```

Faça o mesmo para `superset-worker` e `superset-beat`.

### Passo 2.5: Reiniciar Superset

```bash
cd ~/superset_airflow_env
docker compose restart superset superset-worker superset-beat
docker compose logs -f superset
```

---

## ✈️ Parte 3: Configurar Airflow com OAuth2

### Passo 3.1: Criar Arquivo de Configuração

Crie `airflow/config/webserver_config.py`:

```bash
mkdir -p airflow/config
nano airflow/config/webserver_config.py
```

### Passo 3.2: Adicionar Configuração OAuth

```python
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
            'client_id': 'SEU_AIRFLOW_CLIENT_ID_AQUI',
            'client_secret': 'SEU_AIRFLOW_CLIENT_SECRET_AQUI',
            'api_base_url': 'https://graph.microsoft.com/v1.0/',
            'client_kwargs': {
                'scope': 'openid email profile User.Read'
            },
            'access_token_url': 'https://login.microsoftonline.com/SEU_TENANT_ID_AQUI/oauth2/v2.0/token',
            'authorize_url': 'https://login.microsoftonline.com/SEU_TENANT_ID_AQUI/oauth2/v2.0/authorize',
            'server_metadata_url': 'https://login.microsoftonline.com/SEU_TENANT_ID_AQUI/v2.0/.well-known/openid-configuration',
        }
    }
]

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"  # Papel padrão no Airflow

# Callback de informações do usuário
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
                'role_keys': ['Viewer'],  # Papel padrão
            }

SECURITY_MANAGER_CLASS = AzureSecurityManager

# --------------------------------------------------
# Configurações Adicionais
# --------------------------------------------------

# Roles baseados em grupos do Azure AD (Opcional)
# AUTH_ROLES_MAPPING = {
#     "Airflow-Admins": ["Admin"],
#     "Airflow-Operators": ["Op"],
#     "Airflow-Users": ["Viewer"],
# }

# AUTH_ROLES_SYNC_AT_LOGIN = True
```

### Passo 3.3: Atualizar docker-compose.yml

No serviço `x-airflow-common` (que é herdado por todos os serviços Airflow):

```yaml
x-airflow-common:
  &airflow-common
  image: apache/airflow:2.8.0-python3.11
  environment:
    # ... outras variáveis ...
    AIRFLOW__WEBSERVER__RBAC: 'True'
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.session'
  volumes:
    - ./airflow/dags:/opt/airflow/dags
    - ./airflow/logs:/opt/airflow/logs
    - ./airflow/plugins:/opt/airflow/plugins
    - ./airflow/config:/opt/airflow/config  # Adicionar esta linha
```

E no serviço `airflow-webserver` especificamente:

```yaml
airflow-webserver:
  <<: *airflow-common
  command: webserver
  environment:
    <<: *airflow-common-env
    AIRFLOW__WEBSERVER__CONFIG_FILE: /opt/airflow/config/webserver_config.py  # Adicionar
```

### Passo 3.4: Instalar Dependências

O Airflow precisa do pacote `authlib` para OAuth. Adicione ao Dockerfile ou instale manualmente:

```bash
# Opção 1: Executar no container
docker compose exec airflow-webserver pip install authlib

# Opção 2: Criar requirements.txt
echo "authlib>=1.0.0" > airflow/requirements.txt
```

E adicione ao `docker-compose.yml`:

```yaml
x-airflow-common:
  &airflow-common
  volumes:
    # ... outros volumes ...
    - ./airflow/requirements.txt:/requirements.txt
  command: >
    bash -c "pip install -r /requirements.txt && airflow webserver"
```

### Passo 3.5: Reiniciar Airflow

```bash
docker compose restart airflow-webserver airflow-scheduler
docker compose logs -f airflow-webserver
```

---

## ✅ Parte 4: Testar SSO

### Teste 1: Superset

1. Abra: https://bi.bomgado.com.br
2. Você verá um botão **"Sign in with Azure"** com ícone Windows
3. Clique no botão
4. Será redirecionado para login Microsoft
5. Faça login com credenciais Azure AD
6. Após autenticar, será redirecionado de volta ao Superset logado

### Teste 2: Airflow

1. Abra: https://airflow.bomgado.com.br
2. Clique em **"Sign in with Azure"**
3. Login Microsoft → Redirecionamento → Acesso concedido

### Teste 3: Verificar Usuário Criado

**No Superset:**
```bash
docker compose exec superset superset fab list-users
```

**No Airflow:**
```bash
docker compose exec airflow-webserver airflow users list
```

Você deve ver o usuário criado com email do Azure AD.

---

## 🔧 Troubleshooting

### Erro: "Redirect URI mismatch"

**Causa:** URI de redirecionamento não corresponde ao configurado no Azure.

**Solução:**
1. Verifique o **Redirect URI** no Azure App Registration
2. Deve ser exatamente:
   - Superset: `https://bi.bomgado.com.br/oauth-authorized/azure`
   - Airflow: `https://airflow.bomgado.com.br/oauth-authorized/azure`
3. Não pode ter `/` no final
4. **DEVE usar HTTPS** (Azure Entra ID exige)

### Erro: "Invalid client secret"

**Causa:** Client Secret incorreto ou expirado.

**Solução:**
1. No Azure Portal, vá em **Certificates & secrets**
2. Se expirado, crie um novo Client Secret
3. Atualize `superset_config_azure.py` ou `webserver_config.py`
4. Reinicie os containers

### Erro: "User not found"

**Causa:** `AUTH_USER_REGISTRATION = False` ou problema no mapeamento.

**Solução:**
1. Verifique se `AUTH_USER_REGISTRATION = True`
2. Verifique a função `oauth_user_info` está retornando os campos corretos
3. Veja os logs:
   ```bash
   docker compose logs superset | grep -i oauth
   docker compose logs airflow-webserver | grep -i oauth
   ```

### Erro: "HTTPS required" ou "Redirect URI must use HTTPS"

**Causa:** Azure Entra ID **exige HTTPS** para redirect URIs por segurança.

**Solução:**
1. Configure SSL/TLS (veja seção "Passo 0: Configurar HTTPS")
2. Use certificado Let's Encrypt (gratuito) ou auto-assinado
3. Atualize Redirect URIs no Azure para `https://`
4. Reinicie os containers após configurar SSL

**Não há solução temporária HTTP** - HTTPS é obrigatório.

### Botão "Sign in with Azure" não aparece

**Causa:** Configuração não carregada.

**Solução:**
```bash
# Verificar se arquivo de config existe
docker compose exec superset ls -la /app/pythonpath/
docker compose exec airflow-webserver ls -la /opt/airflow/config/

# Ver logs de inicialização
docker compose logs superset | grep -i config
docker compose logs airflow-webserver | grep -i config
```

### Token expirado rapidamente

**Causa:** Token padrão do Azure expira em 1 hora.

**Solução:**
1. No Azure Portal → App Registration → **Token configuration**
2. Configure **Optional claims** e **Token lifetime policies**
3. Ou implemente token refresh no código

---

## 🎨 Customizações Avançadas

### 1. Mapear Grupos do Azure AD para Roles

Adicione ao `superset_config_azure.py`:

```python
# Mapear grupos do Azure para roles do Superset
AUTH_ROLES_MAPPING = {
    "superset-admins@suaempresa.com": ["Admin"],
    "superset-analysts@suaempresa.com": ["Alpha"],
    "superset-viewers@suaempresa.com": ["Gamma"],
}

AUTH_ROLES_SYNC_AT_LOGIN = True
```

### 2. Obter Grupos do Usuário do Azure

Atualize a função `oauth_user_info`:

```python
def get_oauth_user_info(provider, response):
    if provider == 'azure':
        import requests
        access_token = response.get('access_token')
        
        # Informações do usuário
        me = requests.get(
            'https://graph.microsoft.com/v1.0/me',
            headers={'Authorization': f'Bearer {access_token}'}
        ).json()
        
        # Obter grupos do usuário
        groups = requests.get(
            'https://graph.microsoft.com/v1.0/me/memberOf',
            headers={'Authorization': f'Bearer {access_token}'}
        ).json()
        
        group_names = [g.get('displayName') for g in groups.get('value', [])]
        
        return {
            'username': me.get('userPrincipalName', '').split('@')[0],
            'email': me.get('mail') or me.get('userPrincipalName'),
            'first_name': me.get('givenName', ''),
            'last_name': me.get('surname', ''),
            'role_keys': group_names,  # Passa os grupos como roles
        }
```

**Importante:** Para obter grupos, adicione permissão `GroupMember.Read.All` no Azure App.

### 3. Forçar Login apenas por SSO

Desabilite login local:

```python
# Em superset_config_azure.py
AUTH_TYPE = AUTH_OAUTH
AUTH_USER_REGISTRATION = True
PUBLIC_ROLE_LIKE_GAMMA = False  # Desabilitar auto-registro sem grupo

# Remover botão de login padrão
ENABLE_PROXY_FIX = True
```

### 4. Customizar Botão de Login

```python
# Personalizar texto do botão
OAUTH_PROVIDERS = [
    {
        'name': 'azure',
        'icon': 'fa-windows',
        'label': 'Login com Microsoft',  # Texto customizado
        # ... resto da config
    }
]
```

---

## 📊 Diagrama de Fluxo SSO

```
┌─────────────┐
│   Usuário   │
└──────┬──────┘
       │
       │ 1. Acessa Superset/Airflow
       ▼
┌─────────────────────┐
│ Superset/Airflow    │
│ (Service Provider)  │
└──────┬──────────────┘
       │
       │ 2. Redireciona para Azure
       ▼
┌─────────────────────┐
│  Azure Entra ID     │
│ (Identity Provider) │
└──────┬──────────────┘
       │
       │ 3. Usuário faz login Microsoft
       │ 4. Azure emite token OAuth
       ▼
┌─────────────────────┐
│ Superset/Airflow    │
│ Valida token        │
└──────┬──────────────┘
       │
       │ 5. Cria/atualiza usuário local
       │ 6. Inicia sessão
       ▼
┌─────────────┐
│   Dashboard │
│   (Logado)  │
└─────────────┘
```

---

## 📚 Referências

- [Azure Entra ID OAuth Documentation](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Apache Superset Security](https://superset.apache.org/docs/security/)
- [Apache Airflow Security](https://airflow.apache.org/docs/apache-airflow/stable/security/)
- [Flask-AppBuilder OAuth](https://flask-appbuilder.readthedocs.io/en/latest/security.html#authentication-oauth)

---

## 🆘 Suporte

Se encontrar problemas:

1. Verifique logs detalhados:
   ```bash
   docker compose logs superset | tail -100
   docker compose logs airflow-webserver | tail -100
   ```

2. Teste o endpoint de metadata do Azure:
   ```bash
   curl https://login.microsoftonline.com/SEU_TENANT_ID/v2.0/.well-known/openid-configuration
   ```

3. Valide as permissões no Azure Portal em **API permissions**

4. Confirme que o **Admin consent** foi concedido

---

**SSO configurado com sucesso!** 🎉  
Seus usuários agora podem fazer login com credenciais corporativas Microsoft.
