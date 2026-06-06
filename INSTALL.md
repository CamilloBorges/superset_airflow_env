# Guia de Instalação - Plataforma de Dados

Instalação completa em servidor Ubuntu limpo até ambiente de produção funcionando.

**Tempo total**: 20-30 minutos  
**Dificuldade**: Intermediária  
**Pré-requisitos**: VM Ubuntu + Conta Azure + Cloudflare

---

## 📋 Checklist Pré-instalação

Antes de começar, tenha em mãos:

- [ ] **VM Azure criada**
  - Ubuntu 24.04 LTS (ou 22.04)
  - Standard_B2ms ou superior (2 vCPU, 8GB RAM)
  - 30GB disco Premium SSD
  - IP público (para SSH inicial)
  - Porta 22 liberada

- [ ] **Azure Entra ID configurado**
  - Tenant ID anotado
  - 2 App Registrations criados (Superset + Airflow)
  - Client IDs anotados
  - Client Secrets gerados e anotados
  - Redirect URIs configurados

- [ ] **Cloudflare configurado**
  - Domínio adicionado ao Cloudflare
  - Tunnel criado
  - Token do tunnel copiado
  - DNS apontando para tunnel

---

## 🚀 Instalação Automatizada (Recomendado)

### Passo 1: Conectar à VM

```bash
# Do seu computador local
ssh azureuser@<IP_PUBLICO_VM>
```

### Passo 2: Atualizar Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### Passo 3: Instalar Docker e Docker Compose

```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Aplicar mudanças de grupo
newgrp docker

# Verificar instalação
docker --version
docker compose version
```

### Passo 4: Instalar Cloudflare Tunnel

```bash
# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# Instalar
sudo dpkg -i cloudflared-linux-amd64.deb

# Configurar tunnel (substitua <TOKEN> pelo seu token)
sudo cloudflared service install <TOKEN_DO_CLOUDFLARE>

# Iniciar e habilitar
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Verificar status
sudo systemctl status cloudflared
```

### Passo 5: Clonar Repositório

```bash
cd ~
git clone https://github.com/CamilloBorges/superset_airflow_env.git data-platform
cd data-platform
```

### Passo 6: Configurar Variáveis de Ambiente

```bash
# Copiar template
cp .env.example .env

# Editar com seus valores
nano .env
```

**Edite as seguintes variáveis:**

```bash
# Domínio (seu domínio Cloudflare)
PUBLIC_DOMAIN=bi.bomgado.com.br

# Azure Tenant ID
AZURE_TENANT_ID=0ffb4bbd-7ce2-4e66-b35b-633c7d4ef035

# Superset App Registration
AZURE_SUPERSET_CLIENT_ID=<seu-superset-client-id>
AZURE_SUPERSET_CLIENT_SECRET=<seu-superset-client-secret>

# Airflow App Registration
AZURE_AIRFLOW_CLIENT_ID=<seu-airflow-client-id>
AZURE_AIRFLOW_CLIENT_SECRET=<seu-airflow-client-secret>
```

**Gerar secrets fortes:**

```bash
# Gerar senhas seguras (se quiser trocar as padrões)
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Salve e feche (Ctrl+O, Enter, Ctrl+X).

### Passo 7: Build e Deploy

```bash
# Build da imagem customizada do Superset
docker compose build superset-init

# Iniciar infraestrutura base
docker compose up -d postgres redis

# Aguardar PostgreSQL ficar healthy (30 segundos)
sleep 30

# Verificar se PostgreSQL está saudável
docker compose ps postgres

# Inicializar bancos de dados
docker compose up -d airflow-init superset-init

# Aguardar migrations (60 segundos)
sleep 60

# Subir todos os serviços
docker compose up -d

# Verificar status
docker compose ps
```

**Resultado esperado:**

```
NAME                STATUS              HEALTH
airflow-scheduler   Up X seconds        healthy
airflow-triggerer   Up X seconds        healthy
airflow-webserver   Up X seconds        healthy
airflow-worker      Up X seconds        healthy
hop                 Up X seconds        healthy
nginx               Up X seconds        healthy
postgres            Up X seconds        healthy
redis               Up X seconds        healthy
superset            Up X seconds        healthy
superset-beat       Up X seconds        
superset-worker     Up X seconds        healthy
```

### Passo 8: Verificar Logs

```bash
# Ver logs do Superset
docker compose logs superset --tail 50

# Verificar se configuração foi carregada
docker compose logs superset | grep "Configurações customizadas"

# Ver logs do Airflow
docker compose logs airflow-webserver --tail 50
```

Você deve ver:
- `✓ Configurações customizadas do Superset carregadas com sucesso!`
- Nenhum erro relacionado a OAuth ou Redis
- Serviços marcados como "healthy"

### Passo 9: Configurar Cloudflare Tunnel Routes

No **Cloudflare Dashboard**:

1. Acesse seu tunnel
2. Adicione Public Hostnames:

**Superset:**
- Subdomain: `bi` (ou deixe vazio para root)
- Domain: `bomgado.com.br`
- Type: `HTTP`
- URL: `nginx:80`

**Airflow:**
- Subdomain: `airflow`
- Domain: `bomgado.com.br`
- Type: `HTTP`
- URL: `nginx:8080`

**Hop:**
- Subdomain: `hop`
- Domain: `bomgado.com.br`
- Type: `HTTP`
- URL: `nginx:8081`

### Passo 10: Testar Acesso

1. **Abra navegador** em modo anônimo (cookies limpos)
2. **Acesse**: https://bi.bomgado.com.br
3. **Resultado esperado**:
   - Redirecionamento para `/login/`
   - Botão "Sign in with Microsoft"
4. **Clique** em "Sign in with Microsoft"
5. **Faça login** com sua conta Azure
6. **Confirme**: Usuário criado automaticamente, acesso aos dashboards

Repita para:
- https://airflow.bomgado.com.br
- https://hop.bomgado.com.br (se configurado OAuth)

---

## ✅ Validação da Instalação

### 1. Verificar Containers

```bash
docker compose ps
```

Todos devem estar **Up** e **healthy**.

### 2. Verificar Conectividade

```bash
# Superset local
curl -I http://localhost:8088/health

# Airflow local
curl -I http://localhost:8080/health

# PostgreSQL
docker compose exec postgres pg_isready -U dataplatform

# Redis
docker compose exec redis redis-cli -a $REDIS_PASSWORD ping
```

### 3. Verificar Logs sem Erros

```bash
# Buscar erros nos logs
docker compose logs | grep -i error | grep -v "404"
docker compose logs | grep -i "critical\|fatal"
```

Não deve haver erros críticos.

### 4. Verificar OAuth

```bash
# Verificar se variáveis Azure estão carregadas
docker compose exec superset env | grep AZURE

# Deve mostrar:
# AZURE_TENANT_ID=...
# AZURE_SUPERSET_CLIENT_ID=...
# AZURE_SUPERSET_CLIENT_SECRET=... (parcial)
```

### 5. Verificar Redis Session

```bash
# Conectar ao Redis e verificar sessões
docker compose exec redis redis-cli -a $REDIS_PASSWORD

# No prompt do Redis:
> KEYS superset:*
> KEYS session:*
> exit
```

Deve haver chaves de sessão quando alguém fizer login.

---

## 🐛 Troubleshooting

### OAuth "State not equal" Error

**Sintomas**: Login OAuth falha com erro "CSRF Warning! State not equal"

**Causa**: Sessão Redis não configurada corretamente

**Solução**:
```bash
# 1. Verificar logs
docker compose logs superset | grep -i "session\|redis"

# 2. Verificar se Redis está acessível
docker compose exec superset /app/.venv/bin/python -c "
from redis import Redis
import os
r = Redis(
    host=os.getenv('REDIS_HOST'),
    port=int(os.getenv('REDIS_PORT')),
    password=os.getenv('REDIS_PASSWORD'),
    db=0
)
print('Redis PING:', r.ping())
"

# 3. Se falhar, verificar senha
docker compose exec superset env | grep REDIS

# 4. Reiniciar Superset
docker compose restart superset
```

### Containers não ficam Healthy

**Sintomas**: `docker compose ps` mostra containers sem (healthy)

**Solução**:
```bash
# 1. Ver logs do container específico
docker compose logs <container_name>

# 2. Verificar dependências
docker compose logs postgres
docker compose logs redis

# 3. Reiniciar na ordem correta
docker compose down
docker compose up -d postgres redis
sleep 30
docker compose up -d
```

### Migrations Falhando

**Sintomas**: airflow-init ou superset-init com exit code 1

**Airflow**:
```bash
# Reiniciar migrations
docker compose down airflow-init
docker compose up -d airflow-init
docker compose logs airflow-init
```

**Superset**:
```bash
# Executar manualmente
docker compose exec superset superset db upgrade
docker compose exec superset superset init
```

### Cloudflare Tunnel não Conecta

**Sintomas**: Erro 502 ou 504 ao acessar domínio

**Solução**:
```bash
# 1. Verificar status do cloudflared
sudo systemctl status cloudflared

# 2. Ver logs
sudo journalctl -u cloudflared -n 50

# 3. Se não estiver rodando, reiniciar
sudo systemctl restart cloudflared

# 4. Verificar se Nginx está ouvindo
docker compose exec nginx nginx -t
docker compose ps nginx
```

### Nginx 502 Bad Gateway

**Sintomas**: Cloudflare conecta mas retorna 502

**Solução**:
```bash
# 1. Verificar se backend está UP
docker compose ps superset airflow-webserver hop

# 2. Verificar logs do Nginx
docker compose logs nginx

# 3. Testar conectividade interna
docker compose exec nginx curl -I http://superset:8088/health
docker compose exec nginx curl -I http://airflow-webserver:8080/health

# 4. Reiniciar Nginx
docker compose restart nginx
```

---

## 🔄 Atualizações

### Atualizar Código (sem perder dados)

```bash
cd ~/data-platform
git pull
docker compose build superset-init
docker compose up -d
```

### Atualizar Versões

**Superset**:
```dockerfile
# Editar superset/Dockerfile
FROM apache/superset:6.2.0  # Nova versão
```

**Airflow**:
```yaml
# Editar docker-compose.yml
image: apache/airflow:2.9.0-python3.11  # Nova versão
```

Depois:
```bash
docker compose build
docker compose down
docker compose up -d
```

---

## 💾 Backup e Restore

### Backup

```bash
# Criar diretório de backup
mkdir -p ~/backups

# Backup PostgreSQL
docker compose exec postgres pg_dump -U dataplatform superset_db > ~/backups/superset_$(date +%Y%m%d).sql
docker compose exec postgres pg_dump -U dataplatform airflow_db > ~/backups/airflow_$(date +%Y%m%d).sql

# Backup volumes (alternativa)
docker compose down
sudo tar -czf ~/backups/volumes_$(date +%Y%m%d).tar.gz /var/lib/docker/volumes/data-platform_*
docker compose up -d
```

### Restore

```bash
# Restore PostgreSQL
cat ~/backups/superset_20260606.sql | docker compose exec -T postgres psql -U dataplatform superset_db
cat ~/backups/airflow_20260606.sql | docker compose exec -T postgres psql -U dataplatform airflow_db

# Restart serviços
docker compose restart
```

---

## 🔐 Gestão de Usuários

### Adicionar Admin Manualmente

**Superset**:
```bash
docker compose exec superset superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@bomgado.com.br \
    --password <senha_forte>
```

**Airflow**:
```bash
docker compose exec airflow-webserver airflow users create \
    --username admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@bomgado.com.br \
    --password <senha_forte>
```

### Listar Usuários

**Superset**:
```bash
docker compose exec superset superset fab list-users
```

**Airflow**:
```bash
docker compose exec airflow-webserver airflow users list
```

### Elevar Permissões de Usuário SSO

1. Faça login como admin na interface web
2. Acesse Settings → List Users
3. Encontre o usuário
4. Edit → Role → Selecione novo role (Admin/Alpha)
5. Save

---

## 📊 Monitoramento

### Ver Uso de Recursos

```bash
# Uso de CPU/Memória por container
docker stats

# Tamanho de volumes
docker system df -v

# Espaço em disco
df -h
```

### Logs Contínuos

```bash
# Seguir logs de múltiplos serviços
docker compose logs -f superset airflow-webserver

# Filtrar por erro
docker compose logs -f | grep -i error
```

### Healthchecks

```bash
# Status rápido
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

# Healthcheck manual
curl http://localhost:8088/health
curl http://localhost:8080/health
```

---

## 🎯 Próximos Passos

Após instalação bem-sucedida:

1. **Elevar primeiro usuário a Admin** via interface web
2. **Configurar conexões de banco de dados** no Superset
3. **Criar primeira DAG** no Airflow
4. **Importar projetos Hop** (se aplicável)
5. **Configurar alertas** (opcional)
6. **Setup de backup automatizado**

---

## 📞 Suporte

**Problema não resolvido?**

1. Verifique logs detalhados: `docker compose logs > debug.log`
2. Revise checklist de pré-requisitos
3. Consulte [SETUP_DO_ZERO.md](SETUP_DO_ZERO.md) para análise técnica
4. Abra issue no GitHub com logs

---

**Versão**: 2.0  
**Última atualização**: 2026-06-06  
**Testado em**: Ubuntu 24.04 LTS
