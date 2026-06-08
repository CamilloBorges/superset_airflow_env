# Guia de Instalação - Plataforma de Dados

Este guia detalha a instalação completa em um **servidor Ubuntu zerado**.

## 📋 Pré-requisitos

### Hardware Mínimo
- **CPU**: 4 cores
- **RAM**: 8GB (16GB recomendado para produção)
- **Disco**: 50GB SSD

### Software
- **Ubuntu**: 24.04 LTS ou 22.04 LTS (fresh install)
- **Acesso**: SSH com sudo/root
- **Internet**: Conexão estável

### Opcional (para HTTPS externo)
- Domínio próprio
- Conta Cloudflare (gratuita)
- Cloudflare Tunnel configurado

---

## 🚀 Instalação Automatizada (Recomendado)

### 1. Clonar Repositório

```bash
# SSH no servidor
ssh user@your-server-ip

# Clonar repositório
git clone https://github.com/CamilloBorges/superset_airflow_env.git data-platform
cd data-platform
```

### 2. Executar Script de Instalação

```bash
sudo bash install.sh
```

**O script irá:**
- Atualizar sistema Ubuntu
- Instalar Docker Engine + Compose V2
- Gerar secrets fortes automaticamente
- Criar estrutura de diretórios
- Buildar imagem customizada do Superset
- Inicializar todos os containers
- Aguardar serviços ficarem healthy

**Tempo estimado**: 15-20 minutos (primeira execução)

### 3. Verificar Instalação

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f
```

**Todos os containers devem estar `healthy`**:
- ✅ openldap
- ✅ postgres
- ✅ redis
- ✅ superset
- ✅ airflow-webserver
- ✅ airflow-scheduler
- ✅ hop-server
- ✅ phpldapadmin

---

## 🔧 Instalação Manual (Passo a Passo)

Se preferir controle total sobre cada etapa:

### 1. Atualizar Sistema

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y curl wget git jq python3 python3-pip
```

### 2. Instalar Docker

```bash
# Remover versões antigas
sudo apt-get remove docker docker-engine docker.io containerd runc

# Adicionar repositório Docker
sudo apt-get install ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Verificar
docker --version
docker compose version
```

### 3. Configurar Ambiente

```bash
# Clonar repositório
git clone https://github.com/CamilloBorges/superset_airflow_env.git data-platform
cd data-platform

# Copiar .env
cp .env.example .env

# Gerar secrets
python3 generate_secrets.py
```

### 4. Editar .env (IMPORTANTE!)

```bash
nano .env
```

**Configurações obrigatórias:**

```bash
# LDAP - Defina senhas fortes!
LDAP_ADMIN_PASSWORD=SuaSenhaForteAqui123!
LDAP_CONFIG_PASSWORD=SenhaConfigForte456!
LDAP_READONLY_PASSWORD=SenhaReadOnly789!

# PostgreSQL
POSTGRES_PASSWORD=SenhaPostgresForte!
POSTGRES_PASSWORD_URLENCODED=SenhaPostgresForte!  # ou URL-encoded se tiver caracteres especiais

# Redis
REDIS_PASSWORD=SenhaRedisForte!

# Secrets já gerados por generate_secrets.py
SUPERSET_SECRET_KEY=... # já preenchido
AIRFLOW__CORE__FERNET_KEY=... # já preenchido
AIRFLOW__WEBSERVER__SECRET_KEY=... # já preenchido
```

**Trocar @, :, / em senhas PostgreSQL:**
```bash
# Se senha contém @ encode como %40
# Senha original: Pass@123 → URL-encoded: Pass%40123
POSTGRES_PASSWORD=Pass@123
POSTGRES_PASSWORD_URLENCODED=Pass%40123
```

### 5. Build e Iniciar

```bash
# Build imagem Superset customizada
docker compose build superset-init

# Iniciar todos os serviços
docker compose up -d

# Acompanhar logs
docker compose logs -f
```

### 6. Aguardar Inicialização

**Primeira execução pode levar 10 minutos:**
- OpenLDAP: ~30s
- PostgreSQL: ~20s
- Redis: ~10s
- Superset init: ~2 min
- Airflow init: ~2 min
- Superset: ~3 min
- Airflow: ~3 min

Verificar health:
```bash
docker compose ps
```

---

## 🔐 Configuração Pós-Instalação

### 1. Acessar phpLDAPadmin

**URL**: http://SERVER_IP:8082

**Login:**
- Login DN: `cn=admin,dc=bomgado,dc=local`
- Password: `LDAP_ADMIN_PASSWORD` (do .env)

### 2. Criar Usuários LDAP

**Via phpLDAPadmin (Interface Web):**

1. Navegue até `ou=users,dc=bomgado,dc=local`
2. Click **Create new entry** → **inetOrgPerson**
3. Preencha:
   - **CN** (Common Name): Nome completo (ex: João Silva)
   - **SN** (Surname): Sobrenome (ex: Silva)
   - **UID**: Username para login (ex: joao.silva)
   - **Mail**: Email (ex: joao.silva@empresa.com.br)
   - **Given Name**: Primeiro nome (ex: João)
   - **User Password**: Senha (será criptografada)
4. Click **Add objectClass** → **posixAccount**
5. Adicionar campos POSIX:
   - **uidNumber**: Número único (ex: 10001, 10002, 10003...)
   - **gidNumber**: 10000 (grupo padrão)
   - **homeDirectory**: /home/joao.silva
   - **loginShell**: /bin/bash
6. Click **Create Object**

**Via Linha de Comando:**

```bash
# Criar arquivo user.ldif
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
mail: joao.silva@empresa.com.br
userPassword: senha_temporaria_123
EOF

# Adicionar ao LDAP
cat user.ldif | docker exec -i openldap ldapadd -x \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "${LDAP_ADMIN_PASSWORD}"
```

### 3. Adicionar Usuário a Grupo

```bash
# Adicionar João ao grupo analysts
cat > add_to_group.ldif <<EOF
dn: cn=analysts,ou=groups,dc=bomgado,dc=local
changetype: modify
add: member
member: cn=João Silva,ou=users,dc=bomgado,dc=local
EOF

cat add_to_group.ldif | docker exec -i openldap ldapmodify -x \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "${LDAP_ADMIN_PASSWORD}"
```

### 4. Testar Login

**Superset**: http://SERVER_IP:8088
- Username: `joao.silva` (uid do LDAP)
- Password: senha definida

**Airflow**: http://SERVER_IP:8080
- Username: `joao.silva`
- Password: senha definida

---

## 🌐 Configurar Cloudflare Tunnel (HTTPS Externo)

### 1. Instalar cloudflared

```bash
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

### 2. Criar Tunnel no Dashboard

1. Acesse: https://one.dash.cloudflare.com
2. Zero Trust → Networks → Tunnels
3. **Create a tunnel**
4. Nome: `data-platform`
5. Copie o **token** gerado

### 3. Instalar como Serviço

```bash
sudo cloudflared service install <TOKEN_COPIADO>
```

### 4. Configurar Rotas (config.yml)

```bash
sudo nano /root/.cloudflared/config.yml
```

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  # Superset
  - hostname: bi.seudominio.com.br
    service: http://localhost:8088
    
  # Airflow
  - hostname: airflow.seudominio.com.br
    service: http://localhost:8080
    
  # Hop
  - hostname: hop.seudominio.com.br
    service: http://localhost:8081
    
  # phpLDAPadmin
  - hostname: ldap.seudominio.com.br
    service: http://localhost:8082
  
  # Catch-all (obrigatório)
  - service: http_status:404
```

### 5. Iniciar Tunnel

```bash
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
sudo systemctl status cloudflared
```

### 6. Adicionar DNS no Cloudflare

No dashboard do Tunnel, adicionar rotas públicas:
- `bi.seudominio.com.br`
- `airflow.seudominio.com.br`
- `hop.seudominio.com.br`
- `ldap.seudominio.com.br`

**Pronto!** Acesse via HTTPS com certificado Cloudflare automático.

---

## 🔒 Hardening de Segurança

### 1. Trocar Senhas Padrão

```bash
# Editar .env
nano .env

# Trocar:
LDAP_ADMIN_PASSWORD=...
POSTGRES_PASSWORD=...
REDIS_PASSWORD=...

# Restart
docker compose down
docker compose up -d
```

### 2. Trocar Senha LDAP admin (uid: admin)

**Via phpLDAPadmin:**
1. Navegue até `cn=admin,ou=users,dc=bomgado,dc=local`
2. Click **userPassword**
3. Trocar `admin123` por senha forte

### 3. Configurar Firewall

```bash
# Instalar ufw
sudo apt-get install -y ufw

# Permitir SSH
sudo ufw allow 22/tcp

# Permitir apenas localhost para serviços (se usar Cloudflare Tunnel)
# Não abrir portas 8080, 8081, 8082, 8088 publicamente

# Habilitar
sudo ufw enable
```

### 4. Backup Automatizado

```bash
#!/bin/bash
# backup.sh - Executar via cron diariamente

BACKUP_DIR="/backups/data-platform/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# PostgreSQL
docker exec postgres pg_dumpall -U dataplatform | gzip > "$BACKUP_DIR/postgres.sql.gz"

# LDAP
docker exec openldap slapcat -n 1 | gzip > "$BACKUP_DIR/ldap.ldif.gz"

# Volumes
docker run --rm -v data-platform-postgres:/data -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/postgres-volume.tar.gz -C /data .

# Reter 30 dias
find /backups/data-platform -type d -mtime +30 -exec rm -rf {} \;
```

Agendar:
```bash
sudo crontab -e
# Adicionar:
0 2 * * * /root/data-platform/backup.sh
```

---

## 🛠️ Comandos Úteis

```bash
# Ver status
docker compose ps

# Logs
docker compose logs -f [serviço]

# Restart serviço
docker compose restart superset

# Parar tudo
docker compose down

# Parar e remover volumes (CUIDADO!)
docker compose down -v

# Shell container
docker exec -it superset bash

# Backup LDAP
docker exec openldap slapcat -n 1 > ldap_backup.ldif

# Testar LDAP
docker exec openldap ldapsearch -x -b "dc=bomgado,dc=local" \
  -D "cn=admin,dc=bomgado,dc=local" -w "senha"
```

---

## 🐛 Troubleshooting

### Container não inicia

```bash
# Ver logs
docker compose logs [container]

# Verificar recursos
docker stats

# Reiniciar
docker compose restart [container]
```

### LDAP "Invalid credentials"

```bash
# Verificar LDAP está rodando
docker compose ps openldap

# Testar bind
docker exec openldap ldapwhoami -x \
  -D "cn=admin,dc=bomgado,dc=local" -w "${LDAP_ADMIN_PASSWORD}"
```

### Superset/Airflow não conecta LDAP

```bash
# Ping de superset para openldap
docker exec superset ping openldap

# Verificar env vars
docker exec superset env | grep LDAP
```

### PostgreSQL conexão recusada

```bash
# Health check
docker inspect postgres --format='{{.State.Health.Status}}'

# Conectar manualmente
docker exec -it postgres psql -U dataplatform -d superset_db
```

---

## 📊 Arquitetura Final

```
Internet (HTTPS)
    ↓
Cloudflare Tunnel (TLS termination)
    ↓ http://localhost:8088/8080/8081/8082
┌──────────────┬──────────────┬──────────────┬───────────────┐
│  Superset    │  Airflow     │  Hop         │ phpLDAPadmin │
│  :8088       │  :8080       │  :8081       │  :8082       │
└──────┬───────┴──────┬───────┴──────┬───────┴───────┬───────┘
       │              │              │               │
       └──────────────┴──────────────┴───────────────┘
                      ↓                    ↓
               ┌─────────────┐      ┌──────────┐
               │ PostgreSQL  │      │  Redis   │
               │    :5432    │      │  :6379   │
               └─────────────┘      └──────────┘
                      ↑
               ┌─────────────┐
               │  OpenLDAP   │  ← Autenticação Unificada
               │    :389     │
               └─────────────┘
```

---

## 📚 Referências

- [Apache Superset](https://superset.apache.org/docs/intro)
- [Apache Airflow](https://airflow.apache.org/docs/)
- [Apache Hop](https://hop.apache.org/manual/latest/)
- [OpenLDAP](https://www.openldap.org/doc/admin24/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

## 🆘 Suporte

Problemas? Abra uma [issue](https://github.com/CamilloBorges/superset_airflow_env/issues) ou consulte README.md.
