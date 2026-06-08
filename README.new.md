# Plataforma de Dados Empresarial

Ambiente completo de Business Intelligence e Engenharia de Dados com autenticação unificada:

- **Apache Superset 6.1.0** - Visualização e BI
- **Apache Airflow 2.8.0** - Orquestração de workflows
- **Apache Hop 2.7.0** - ETL/ELT
- **PostgreSQL 15** - Banco de metadados
- **Redis 7** - Cache e message broker
- **OpenLDAP** - Servidor de autenticação centralizada
- **phpLDAPadmin** - Interface web para gerenciar usuários/grupos
- **Cloudflare Tunnel** - Acesso seguro HTTPS

## 🏗️ Arquitetura

```
Internet (HTTPS)
    ↓
Cloudflare Edge (SSL/TLS + DDoS Protection)
    ↓
Cloudflare Tunnel (encrypted, no public ports)
    ↓
Ubuntu Server / Docker Host
    ↓
┌─────────────┬─────────────┬─────────────┬──────────────────┐
│  Superset   │   Airflow   │     Hop     │  phpLDAPadmin   │
│   :8088     │   :8080     │   :8081     │      :8082      │
└──────┬──────┴──────┬──────┴──────┬──────┴────────┬─────────┘
       │             │             │               │
       └─────────────┴─────────────┴───────────────┘
                     ↓               ↓
              ┌─────────────┐  ┌──────────┐
              │  PostgreSQL │  │  Redis   │
              │    :5432    │  │  :6379   │
              └─────────────┘  └──────────┘
                     ↑
              ┌─────────────┐
              │  OpenLDAP   │
              │    :389     │
              └─────────────┘
```

**Acessos via Cloudflare Tunnel:**
- Superset: https://bi.bomgado.com.br
- Airflow: https://airflow.bomgado.com.br
- Hop: https://hop.bomgado.com.br
- LDAP Admin: https://ldap.bomgado.com.br

**Autenticação Unificada:**
- Todos os serviços (Superset, Airflow, Hop) autenticam via OpenLDAP
- Gerenciamento centralizado de usuários e permissões
- Sincronização automática de roles baseada em grupos LDAP

---

## 🚀 Instalação Rápida

```bash
# 1. Clone o repositório
git clone https://github.com/CamilloBorges/superset_airflow_env.git data-platform
cd data-platform

# 2. Configure variáveis de ambiente
cp .env.ldap.example .env
nano .env

# 3. Gere secrets fortes
python3 generate_secrets.py

# 4. Inicialize o ambiente
docker compose up -d

# 5. Aguarde inicialização (~5 minutos)
docker compose logs -f
```

**Pronto!** Acesse via Cloudflare Tunnel configurado.

---

## 📋 Pré-requisitos

### Servidor
- Ubuntu 24.04 LTS (ou 22.04/Debian 12)
- 8GB RAM mínimo (16GB recomendado para produção)
- 50GB disco SSD
- Docker Engine 24.0+ e Docker Compose v2
- Acesso SSH com sudo

### Cloudflare
- Conta Cloudflare (gratuita ou paga)
- Domínio gerenciado pelo Cloudflare
- Cloudflare Tunnel criado

### Opcional
- Backup automático configurado para volumes Docker
- Monitoramento (Prometheus/Grafana)

---

## 📁 Estrutura do Projeto

```
data-platform/
├── .env                          # Variáveis de ambiente (NÃO commitado)
├── .env.ldap.example             # Template de variáveis com LDAP
├── docker-compose.yml            # Orquestração completa
├── airflow/
│   ├── config/
│   │   └── webserver_config_ldap.py   # Autenticação LDAP
│   ├── dags/                          # DAGs do Airflow
│   ├── logs/                          # Logs (persistente)
│   └── plugins/                       # Plugins customizados
├── superset/
│   ├── Dockerfile                     # Superset customizado
│   ├── config/
│   │   └── superset_config_ldap.py    # Autenticação LDAP
│   └── data/                          # Dashboards e uploads
├── hop/
│   ├── config/                        # Configurações Hop
│   ├── projects/                      # Projetos Hop
│   └── metadata/                      # Metadata store
├── ldap/
│   └── bootstrap.ldif                 # Estrutura inicial LDAP
├── postgres/
│   └── init-scripts/
│       └── 01-init-databases.sh       # Criação de DBs
└── shared/
    └── data/                          # Dados compartilhados
```

---

## 🔐 Gerenciamento de Usuários LDAP

### Estrutura Organizacional

```
dc=bomgado,dc=local
├── ou=users                    # Usuários do sistema
│   └── cn=admin                # Usuário admin padrão
├── ou=groups                   # Grupos de segurança
│   ├── cn=admins               # Administradores (role Admin)
│   ├── cn=analysts             # Analistas (role Alpha/Op)
│   └── cn=viewers              # Visualizadores (role Gamma/Viewer)
└── ou=services                 # Contas de serviço
```

### Acessar phpLDAPadmin

1. Acesse: https://ldap.bomgado.com.br
2. Login DN: `cn=admin,dc=bomgado,dc=local`
3. Password: `${LDAP_ADMIN_PASSWORD}` (do .env)

### Adicionar Novo Usuário

**Via phpLDAPadmin (Interface Web):**
1. Navegue até `ou=users,dc=bomgado,dc=local`
2. Create new entry → inetOrgPerson
3. Preencha:
   - `cn`: nome completo
   - `sn`: sobrenome
   - `uid`: username (usado para login)
   - `mail`: email
   - `givenName`: primeiro nome
   - `userPassword`: senha (será criptografada automaticamente)
4. Add objectClass: `posixAccount`
5. Adicione atributos POSIX: `uidNumber`, `gidNumber`, `homeDirectory`

**Via linha de comando (ldapadd):**
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
mail: joao.silva@bomgado.com.br
userPassword: senha_temporaria_123
EOF

# Adicionar ao LDAP
docker exec -i openldap ldapadd -x -D "cn=admin,dc=bomgado,dc=local" \
  -w "${LDAP_ADMIN_PASSWORD}" -f /tmp/user.ldif
```

### Adicionar Usuário a Grupo

```bash
# Adicionar João ao grupo analysts
cat > add_to_group.ldif <<EOF
dn: cn=analysts,ou=groups,dc=bomgado,dc=local
changetype: modify
add: member
member: cn=João Silva,ou=users,dc=bomgado,dc=local
EOF

docker exec -i openldap ldapmodify -x -D "cn=admin,dc=bomgado,dc=local" \
  -w "${LDAP_ADMIN_PASSWORD}" -f /tmp/add_to_group.ldif
```

### Mapeamento de Grupos para Roles

| Grupo LDAP | Superset Role | Airflow Role | Descrição |
|------------|---------------|--------------|-----------|
| `admins` | Admin | Admin | Acesso total, gerenciar usuários |
| `analysts` | Alpha, Gamma | Op, User | Criar dashboards, editar DAGs |
| `viewers` | Gamma | Viewer | Visualizar dashboards/DAGs |

**Sincronização automática**: roles são atualizados a cada login.

---

## 🔧 Configuração do Cloudflare Tunnel

### 1. Instalar cloudflared

```bash
# Ubuntu/Debian
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

### 2. Criar Tunnel no Dashboard Cloudflare

1. Acesse Cloudflare Zero Trust → Networks → Tunnels
2. Create a tunnel → Nome: `data-platform-tunnel`
3. Copie o token gerado

### 3. Configurar Roteamento

**config.yml:**
```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  # Superset
  - hostname: bi.bomgado.com.br
    service: http://localhost:8088
    
  # Airflow
  - hostname: airflow.bomgado.com.br
    service: http://localhost:8080
    
  # Hop
  - hostname: hop.bomgado.com.br
    service: http://localhost:8081
    
  # phpLDAPadmin
  - hostname: ldap.bomgado.com.br
    service: http://localhost:8082
  
  # Catch-all (obrigatório)
  - service: http_status:404
```

### 4. Executar como Serviço

```bash
# Instalar como serviço systemd
sudo cloudflared service install

# Iniciar
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Verificar status
sudo systemctl status cloudflared
```

---

## 🔧 Comandos Úteis

```bash
# Iniciar ambiente
docker compose up -d

# Ver logs de todos os serviços
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f superset

# Reiniciar serviço específico
docker compose restart superset

# Parar ambiente
docker compose down

# Parar e remover volumes (CUIDADO: apaga dados!)
docker compose down -v

# Acessar shell do container
docker exec -it superset bash
docker exec -it openldap bash

# Backup do LDAP
docker exec openldap slapcat -n 1 > ldap_backup_$(date +%Y%m%d).ldif

# Restaurar LDAP
docker exec -i openldap slapadd -n 1 < ldap_backup_20260608.ldif

# Verificar saúde dos containers
docker compose ps
```

---

## 🛠️ Troubleshooting

### LDAP - "Invalid credentials"

```bash
# Testar autenticação LDAP
docker exec openldap ldapsearch -x -H ldap://localhost \
  -b "dc=bomgado,dc=local" \
  -D "cn=admin,dc=bomgado,dc=local" \
  -w "${LDAP_ADMIN_PASSWORD}"

# Verificar logs
docker logs openldap
```

### Superset - "Connection refused"

```bash
# Verificar se Superset conecta no LDAP
docker exec superset ping openldap

# Testar configuração LDAP do Superset
docker exec superset python3 -c "
from ldap3 import Server, Connection
server = Server('openldap', port=389)
conn = Connection(server, 'cn=admin,dc=bomgado,dc=local', 'senha')
print('OK' if conn.bind() else 'FALHOU')
"
```

### Airflow - Usuário LDAP não aparece

```bash
# Forçar sincronização de usuários LDAP
docker exec airflow-webserver airflow users list
docker exec airflow-webserver airflow sync-perm
```

### PostgreSQL - Banco não inicializa

```bash
# Verificar logs de inicialização
docker logs postgres

# Conectar manualmente
docker exec -it postgres psql -U dataplatform -d superset_db
```

---

## 📊 Monitoramento

### Health Checks

Todos os containers possuem health checks configurados:

```bash
# Ver status de saúde
docker compose ps

# Verificar health check individual
docker inspect --format='{{json .State.Health}}' superset | jq
```

### Métricas

- **Superset**: `http://localhost:8088/health`
- **Airflow**: `http://localhost:8080/health`
- **PostgreSQL**: `pg_isready -U dataplatform`
- **Redis**: `redis-cli ping`
- **OpenLDAP**: `ldapsearch -x -b "dc=bomgado,dc=local"`

---

## 🔒 Segurança

### Checklist Produção

- [ ] Alterar todas as senhas padrão no `.env`
- [ ] Gerar `SUPERSET_SECRET_KEY` forte (42+ caracteres)
- [ ] Gerar `AIRFLOW__CORE__FERNET_KEY` via `cryptography.fernet`
- [ ] Configurar backup automático dos volumes Docker
- [ ] Habilitar firewall (ufw) e permitir apenas portas essenciais
- [ ] Configurar rate limiting no Cloudflare
- [ ] Habilitar Cloudflare WAF
- [ ] Rotacionar secrets regularmente
- [ ] Configurar alertas de falha de login (Cloudflare Access Logs)
- [ ] Revisar roles LDAP periodicamente

### Hardening LDAP

```bash
# Forçar senhas fortes via política
# Desabilitar acesso anônimo (já configurado)
# Habilitar auditoria de acessos
```

---

## 📦 Backup e Restore

### Backup Automatizado

```bash
#!/bin/bash
# backup.sh - Executar via cron diariamente

BACKUP_DIR="/backups/data-platform/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
docker exec postgres pg_dumpall -U dataplatform | gzip > "$BACKUP_DIR/postgres.sql.gz"

# Backup LDAP
docker exec openldap slapcat -n 1 | gzip > "$BACKUP_DIR/ldap.ldif.gz"

# Backup volumes
docker run --rm -v data-platform-postgres:/data -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/postgres-volume.tar.gz -C /data .

docker run --rm -v data-platform-ldap:/data -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/ldap-volume.tar.gz -C /data .

# Reter últimos 30 dias
find /backups/data-platform -type d -mtime +30 -exec rm -rf {} \;
```

### Restaurar Backup

```bash
# PostgreSQL
gunzip < postgres.sql.gz | docker exec -i postgres psql -U dataplatform

# LDAP
docker compose stop openldap
docker volume rm data-platform-ldap
docker compose up -d openldap
gunzip < ldap.ldif.gz | docker exec -i openldap slapadd -n 1
docker compose restart openldap
```

---

## 📚 Documentação Adicional

- [Apache Superset Docs](https://superset.apache.org/docs/intro)
- [Apache Airflow Docs](https://airflow.apache.org/docs/)
- [Apache Hop Docs](https://hop.apache.org/manual/latest/)
- [OpenLDAP Admin Guide](https://www.openldap.org/doc/admin24/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:
1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

---

## 📄 Licença

Este projeto utiliza componentes open-source:
- Apache Superset: Apache License 2.0
- Apache Airflow: Apache License 2.0
- Apache Hop: Apache License 2.0
- OpenLDAP: OpenLDAP Public License
- PostgreSQL: PostgreSQL License
- Redis: BSD License

---

## 👤 Autor

**Plataforma de Dados Bomgado**  
📧 admin@bomgado.com.br  
🌐 [bomgado.com.br](https://bomgado.com.br)

---

## 🆘 Suporte

Problemas? Abra uma [issue](https://github.com/CamilloBorges/superset_airflow_env/issues) ou consulte:
- [Troubleshooting Guide](#-troubleshooting)
- [FAQ](docs/FAQ.md)
- Email: suporte@bomgado.com.br
