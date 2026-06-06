# 🔧 Setup do Zero - Plataforma de Dados

**Data da Análise**: 6 de Junho de 2026  
**Versão do Repositório**: Commit 5e29e6b  
**Premissa**: VM nova, ambiente limpo, começar do zero

---

## 📊 Análise do Repositório Atual

### ✅ O que está BOM

#### Estrutura e Documentação
- ✅ Estrutura de pastas bem organizada (airflow/, superset/, hop/, nginx/, postgres/)
- ✅ `.env.example` completo com todas as variáveis necessárias
- ✅ Documentação extensa (15+ arquivos .md)
- ✅ Scripts de automação (install.sh, configure-*.sh)
- ✅ `docker-compose.yml` bem estruturado com healthchecks
- ✅ Dockerfiles customizados (Superset com authlib + psycopg2-binary)
- ✅ Exemplos de configuração (`*_azure.py.example`, `webserver_config.py.example`)
- ✅ `.gitignore` configurado corretamente (.env não commitado)

#### Infraestrutura
- ✅ PostgreSQL 15-alpine com scripts de inicialização
- ✅ Redis 7-alpine com senha
- ✅ Nginx configurado como reverse proxy
- ✅ Healthchecks configurados para todos os serviços
- ✅ Networks Docker isoladas
- ✅ Volumes persistentes mapeados
- ✅ Timezone configurável

---

### ⚠️ O que precisa CORRIGIR

#### 1. **Variáveis de Ambiente Azure SSO**

**Problema**: `.env` atual NÃO tem variáveis Azure configuradas

❌ **Faltando no `.env`**:
```bash
# Essas linhas existem no .env.example mas NÃO estão no .env
PUBLIC_DOMAIN=bi.bomgado.com.br
AZURE_TENANT_ID=0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035
AZURE_SUPERSET_CLIENT_ID=<UUID do App Registration>
AZURE_SUPERSET_CLIENT_SECRET=<Secret do App Registration>
AZURE_AIRFLOW_CLIENT_ID=<UUID do App Registration>
AZURE_AIRFLOW_CLIENT_SECRET=<Secret do App Registration>
```

---

#### 2. **Configuração Superset Atual Comprometida**

**Problema**: `superset/config/superset_config.py` tem múltiplas tentativas de fix

❌ **Issues**:
```python
# Linha 31: CSRF desabilitado temporariamente (INSEGURO!)
WTF_CSRF_EXEMPT_LIST = ['.*login.*', '.*oauth.*']

# Linhas 41-48: Session Redis configurada mas não funcionando
SESSION_TYPE = 'redis'
SESSION_REDIS = redis.from_url(...)  # URL string, não objeto Redis

# Linhas 55-74: FLASK_APP_MUTATOR chamando Session(app) tarde demais
def FLASK_APP_MUTATOR(app):
    # ProxyFix está OK
    Session(app)  # Chamado DEPOIS que Flask-AppBuilder já inicializou
```

**Raiz do Problema**: Flask-AppBuilder + Authlib precisam que SESSION_TYPE esteja configurado ANTES da inicialização. A abordagem atual configura muito tarde no ciclo de vida do app.

---

#### 3. **Configuração Airflow OAuth Faltando**

**Problema**: Arquivo `airflow/config/webserver_config.py` NÃO existe (só .example)

❌ **Situação atual**:
```
airflow/config/
├── webserver_config.py.example  ✅ Existe (template)
└── webserver_config.py          ❌ NÃO EXISTE (necessário)
```

**Impacto**: Airflow não terá OAuth habilitado mesmo com variáveis Azure configuradas.

---

#### 4. **Versões Desatualizadas**

**Problema**: docker-compose.yml usa versões antigas

❌ **Versões atuais no código**:
```yaml
image: apache/airflow:2.8.0-python3.11    # Atual: 3.2.2
FROM apache/superset:6.1.0                 # OK (última versão)
```

**Observação**: Airflow 3.x tem breaking changes na configuração OAuth.

---

### 🔍 Problema ROOT CAUSE do OAuth

**Por que o login OAuth não funciona?**

```
1. GET /login/azure
   ↓
2. Flask cria OAuth state e salva na SESSÃO
   ↓
3. Redirect para login.microsoftonline.com
   ↓
4. Usuário faz login no Azure
   ↓
5. Azure redireciona para /oauth-authorized/azure?code=XXX&state=YYY
   ↓
6. Flask lê state da SESSÃO para validar
   ❌ ERRO: "State not equal" - Sessão perdida!
```

**Por que a sessão se perde?**

**Configuração ERRADA** (atual):
```python
# superset_config.py
SESSION_TYPE = 'redis'                    # Variável global
SESSION_REDIS = redis.from_url("...")    # String, não objeto Redis

def FLASK_APP_MUTATOR(app):
    Session(app)  # Chamado TARDE (Flask-AppBuilder já inicializou)
```

**Problema**: Flask-Session precisa ser configurado ANTES que Flask-AppBuilder crie suas blueprints OAuth. A configuração atual:
1. Define SESSION_TYPE como variável global (OK)
2. Define SESSION_REDIS como string (❌ errado, precisa ser objeto Redis)
3. Chama Session(app) dentro de FLASK_APP_MUTATOR (❌ muito tarde)

**Consequência**: Flask usa sessão em MEMÓRIA (padrão), não Redis. Quando request vai para Azure e volta, pode cair em worker diferente do Gunicorn = sessão perdida = state mismatch.

---

## 🎯 Plano de Ação - Setup do Zero

### Fase 1: Preparação do Repositório (Local)

#### 1.1. Corrigir `.env`
```bash
# Copiar .env.example e adicionar variáveis Azure
cp .env.example .env

# Adicionar/editar no .env:
PUBLIC_DOMAIN=bi.bomgado.com.br
AZURE_TENANT_ID=0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035
AZURE_SUPERSET_CLIENT_ID=<obter do Azure Portal>
AZURE_SUPERSET_CLIENT_SECRET=<obter do Azure Portal>
AZURE_AIRFLOW_CLIENT_ID=<obter do Azure Portal>
AZURE_AIRFLOW_CLIENT_SECRET=<obter do Azure Portal>
```

#### 1.2. Recriar `superset_config.py` do Zero
```python
# Usar superset_config_azure.py.example como base
# Adicionar configuração CORRETA de Redis Session
# Remover CSRF_EXEMPT_LIST temporário
# Adicionar PUBLIC_ROLE_LIKE = None (forçar autenticação)
```

#### 1.3. Criar `airflow/config/webserver_config.py`
```bash
# Copiar do template
cp airflow/config/webserver_config.py.example airflow/config/webserver_config.py
```

#### 1.4. Atualizar `docker-compose.yml`
```yaml
# Opcional: Atualizar Airflow 2.8.0 → 3.2.2
# (verificar breaking changes antes)
image: apache/airflow:3.2.2-python3.11
```

---

### Fase 2: Setup da VM (Azure)

#### 2.1. Criar VM Nova no Azure
```bash
# Especificações:
OS: Ubuntu 24.04 LTS
Size: Standard_B2ms (2 vCPU, 8GB RAM)
Disk: 30GB Premium SSD
Network: Permitir SSH (22)
Public IP: Sim (para SSH inicial)
```

#### 2.2. Instalar Docker + Docker Compose
```bash
# Script de instalação limpo
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 2.3. Configurar Cloudflare Tunnel
```bash
# Instalar cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Configurar tunnel (obter token do Cloudflare Dashboard)
sudo cloudflared service install <TOKEN>
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

---

### Fase 3: Deploy da Plataforma

#### 3.1. Clonar Repositório
```bash
cd ~
git clone https://github.com/CamilloBorges/superset_airflow_env.git data-platform
cd data-platform
```

#### 3.2. Transferir `.env` Configurado
```bash
# Do local para servidor (substituir valores)
scp .env azureuser@<IP_VM>:~/data-platform/
```

#### 3.3. Build e Inicializar
```bash
# Build da imagem customizada do Superset
sudo docker compose build superset-custom

# Inicializar banco de dados
sudo docker compose up -d postgres redis
sleep 30  # Aguardar PostgreSQL healthy

# Inicializar Airflow e Superset
sudo docker compose up -d airflow-init superset-init
sleep 60  # Aguardar migrations

# Subir todos os serviços
sudo docker compose up -d

# Verificar status
sudo docker compose ps
sudo docker compose logs superset --tail 50
sudo docker compose logs airflow-webserver --tail 50
```

---

### Fase 4: Configuração Azure App Registrations

#### 4.1. Superset App Registration
```
Nome: bi-bomgado-superset
Redirect URI: https://bi.bomgado.com.br/oauth-authorized/azure
Web: Sim
Scopes: openid, email, profile, User.Read
Client Secret: Criar e copiar para .env
```

#### 4.2. Airflow App Registration
```
Nome: airflow-bomgado
Redirect URI: https://airflow.bomgado.com.br/oauth-authorized/azure
Web: Sim
Scopes: openid, email, profile, User.Read
Client Secret: Criar e copiar para .env
```

---

### Fase 5: Validação e Testes

#### 5.1. Testes de Conectividade
```bash
# Verificar se serviços estão healthy
sudo docker compose ps

# Testar endpoints locais
curl http://localhost:8088/health  # Superset
curl http://localhost:8080/health  # Airflow
```

#### 5.2. Testes OAuth
```
1. Acesse: https://bi.bomgado.com.br
2. Verifique redirecionamento para /login/
3. Clique em "Sign in with Microsoft"
4. Faça login com usuário Azure
5. Confirme criação automática do usuário
6. Verifique acesso aos dashboards
```

---

## 📝 Arquivos que Preciso CRIAR/CORRIGIR

### 🔴 CRÍTICO - Corrigir Imediatamente

1. **`superset/config/superset_config.py`** - RECRIAR do zero
   - Remover tentativas de fix anteriores
   - Configurar Redis Session CORRETAMENTE
   - Adicionar ProxyFix correto
   - Remover CSRF_EXEMPT_LIST temporário
   - Adicionar PUBLIC_ROLE_LIKE = None

2. **`.env`** - ADICIONAR variáveis Azure
   - PUBLIC_DOMAIN
   - AZURE_TENANT_ID
   - AZURE_SUPERSET_CLIENT_ID
   - AZURE_SUPERSET_CLIENT_SECRET
   - AZURE_AIRFLOW_CLIENT_ID
   - AZURE_AIRFLOW_CLIENT_SECRET

3. **`airflow/config/webserver_config.py`** - CRIAR
   - Copiar de webserver_config.py.example
   - Ativar OAuth com Azure

### 🟡 OPCIONAL - Melhorias Futuras

4. **`docker-compose.yml`** - ATUALIZAR versões
   - Airflow 2.8.0 → 3.2.2 (verificar breaking changes)

---

## ✅ Checklist de Setup Limpo

### Pré-Deploy (Local)
- [ ] Variáveis Azure no `.env` configuradas
- [ ] `superset_config.py` recriado com sessão Redis correta
- [ ] `airflow/config/webserver_config.py` criado
- [ ] Commit das configurações limpas
- [ ] Push para GitHub

### Preparação da VM
- [ ] VM criada no Azure (Ubuntu 24.04)
- [ ] Docker + Docker Compose instalados
- [ ] Cloudflare Tunnel configurado
- [ ] DNS apontando para tunnel

### Deploy
- [ ] Repositório clonado na VM
- [ ] `.env` transferido ou configurado
- [ ] Build da imagem Superset custom
- [ ] PostgreSQL e Redis iniciados
- [ ] Migrations executadas (airflow-init, superset-init)
- [ ] Todos os serviços UP e healthy

### Configuração Azure
- [ ] App Registration Superset criado
- [ ] Redirect URI Superset configurado
- [ ] Client Secret Superset gerado
- [ ] App Registration Airflow criado  
- [ ] Redirect URI Airflow configurado
- [ ] Client Secret Airflow gerado

### Validação
- [ ] Superset acessível via https://bi.bomgado.com.br
- [ ] Login OAuth Superset funcionando
- [ ] Usuário criado automaticamente no Superset
- [ ] Airflow acessível via https://airflow.bomgado.com.br
- [ ] Login OAuth Airflow funcionando
- [ ] Dashboards protegidos (requerem autenticação)

---

## 🚨 Erros Comuns a Evitar

### 1. Session Redis Configuration
❌ **ERRADO**:
```python
SESSION_REDIS = redis.from_url("redis://...")  # String em global scope
```

✅ **CORRETO**:
```python
from redis import Redis
SESSION_TYPE = 'redis'
SESSION_REDIS = Redis(
    host=os.getenv('REDIS_HOST'),
    port=int(os.getenv('REDIS_PORT')),
    password=os.getenv('REDIS_PASSWORD'),
    db=0
)
```

### 2. Session Initialization Timing
❌ **ERRADO**:
```python
def FLASK_APP_MUTATOR(app):
    app.config['SESSION_TYPE'] = 'redis'  # Tarde demais!
    Session(app)
```

✅ **CORRETO**:
```python
# Config global (top-level)
SESSION_TYPE = 'redis'
SESSION_REDIS = Redis(...)

# FLASK_APP_MUTATOR apenas para middleware
def FLASK_APP_MUTATOR(app):
    from werkzeug.middleware.proxy_fix import ProxyFix
    app.wsgi_app = ProxyFix(app.wsgi_app, ...)
```

### 3. PUBLIC_ROLE_LIKE Security Issue
❌ **ERRADO**:
```python
PUBLIC_ROLE_LIKE = "Gamma"  # Acesso sem autenticação!
```

✅ **CORRETO**:
```python
# Não definir PUBLIC_ROLE_LIKE ou usar None
# Força autenticação obrigatória
```

### 4. CSRF Exempt List
❌ **ERRADO**:
```python
WTF_CSRF_EXEMPT_LIST = ['.*login.*', '.*oauth.*']  # Inseguro!
```

✅ **CORRETO**:
```python
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = []  # Lista vazia = CSRF em todos endpoints
```

---

## 📚 Próximos Passos

Quando você avisar que a VM está pronta, vou:

1. ✅ Criar `superset_config.py` CORRETO do zero
2. ✅ Criar `airflow/config/webserver_config.py`
3. ✅ Atualizar `.env.example` com PUBLIC_DOMAIN
4. ✅ Commit das configurações limpas
5. ✅ Guia de deploy passo-a-passo para VM nova

---

**Aguardando confirmação de VM pronta para prosseguir! 🚀**
