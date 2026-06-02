# 🚀 Guia de Instalação Automatizada

**Nova forma simplificada de instalar toda a plataforma!**

---

## 📋 Pré-requisitos Mínimos

- **Ubuntu Server 20.04/22.04** (limpo ou existente)
- **Acesso SSH** ao servidor
- **Conta Cloudflare** (opcional mas recomendado)
- **Conta Azure** (opcional, apenas para SSO)

---

## ⚡ Instalação Rápida (Modo Automático)

### Opção 1: Instalação Totalmente Automática

**Use quando:** Primeira instalação em servidor limpo com Cloudflare Tunnel

```bash
# SSH no servidor
ssh -i ~/.ssh/key.pem user@server

# Clone o repositório
git clone <url-repositorio> data-platform
cd data-platform

# Executar instalação automática
chmod +x install.sh
./install.sh --auto
```

**⚠️ IMPORTANTE - Permissões Docker:**
- O script NÃO deve ser executado com `sudo`
- O script detecta automaticamente se você precisa de permissões Docker
- Durante a instalação, usará `sudo docker` apenas para comandos necessários
- Após logout/login, não precisará mais de `sudo` para Docker

**O que será instalado automaticamente:**
- ✅ Dependências do sistema (curl, git, etc)
- ✅ Docker e Docker Compose
- ✅ Secrets de segurança (gerados automaticamente)
- ✅ Estrutura de diretórios
- ✅ Permissões corretas
- ✅ Containers Docker (13 services)
- ✅ Testes de funcionamento

**Tempo:** ~15-20 minutos

---

### Opção 2: Instalação com Arquivo de Configuração

**Use quando:** Quer customizar a instalação ou fazer deploy repetível

#### Passo 1: Criar arquivo de configuração

```bash
# Copiar template
cp install.config.example install.config

# Editar configuração
nano install.config
```

**Configure os valores principais:**
```bash
PUBLIC_DOMAIN=bi.bomgado.com.br
SETUP_CLOUDFLARE=yes
CLOUDFLARE_TUNNEL_TOKEN=<seu-token-aqui>
AUTO_GENERATE_SECRETS=yes
SETUP_AZURE_SSO=no  # Mude para yes se quiser SSO
```

#### Passo 2: Executar instalação

```bash
chmod +x install.sh
./install.sh --config install.config
```

**Tempo:** ~15-20 minutos (automatizado)

---

### Opção 3: Instalação Interativa

**Use quando:** Quer controle sobre cada etapa

```bash
chmod +x install.sh
./install.sh
```

O script irá perguntar:
- Domínio público
- Configurar Cloudflare Tunnel? (token)
- Configurar Azure SSO? (credenciais)
- Confirmar cada etapa importante

**Tempo:** ~20-30 minutos

---

## ☁️ Configuração do Cloudflare Tunnel

### Antes de instalar, obtenha o token:

1. Acesse https://dash.cloudflare.com
2. Selecione: **bomgado.com.br**
3. Menu: **Zero Trust** → **Access** → **Tunnels**
4. Clique **Create a tunnel**
5. Nome: `bi-bomgado-data-platform`
6. Copie o **token** (usado no install.config ou durante instalação)

### Configure Public Hostnames no Cloudflare:

| Subdomain | Domain | Type | URL |
|-----------|--------|------|-----|
| `bi` | `bomgado.com.br` | HTTP | `localhost:80` |
| `airflow` | `bomgado.com.br` | HTTP | `localhost:8080` |
| `hop` | `bomgado.com.br` | HTTP | `localhost:8081` |

**Salve** o tunnel.

---

## 🔐 Configuração do Azure Entra SSO (Opcional)

Se `SETUP_AZURE_SSO=yes` no install.config:

### Antes de instalar, crie os App Registrations:

#### 1. Superset App Registration

- Azure Portal → App Registrations → New
- Nome: `Apache Superset SSO`
- Redirect URI: `https://bi.bomgado.com.br/oauth-authorized/azure`
- Copie: **Client ID** e **Client Secret**

#### 2. Airflow App Registration

- Azure Portal → App Registrations → New
- Nome: `Apache Airflow SSO`
- Redirect URI: `https://airflow.bomgado.com.br/oauth-authorized/azure`
- Copie: **Client ID** e **Client Secret**

#### 3. Adicione ao install.config:

```bash
SETUP_AZURE_SSO=yes
AZURE_TENANT_ID=seu-tenant-id
AZURE_SUPERSET_CLIENT_ID=superset-client-id
AZURE_SUPERSET_CLIENT_SECRET=superset-secret
AZURE_AIRFLOW_CLIENT_ID=airflow-client-id
AZURE_AIRFLOW_CLIENT_SECRET=airflow-secret
```

---

## 📝 Arquivo de Configuração Completo (install.config)

```bash
# ==== INSTALAÇÃO PADRÃO COM CLOUDFLARE ====
PUBLIC_DOMAIN=bi.bomgado.com.br
TIMEZONE=America/Sao_Paulo
INSTALL_MODE=auto

# Docker
INSTALL_DOCKER=yes
CONFIGURE_DOCKER_PERMISSIONS=yes

# Cloudflare Tunnel
SETUP_CLOUDFLARE=yes
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiLi4uIiwidCI6Ii4uLiJ9  # Substitua

# Segurança
AUTO_GENERATE_SECRETS=yes

# SSL (skip com Cloudflare)
SETUP_SSL=skip

# Azure SSO (opcional)
SETUP_AZURE_SSO=no

# Testes
RUN_TESTS=yes
STARTUP_WAIT_TIME=120
```

---

## ✅ Verificação Pós-Instalação

### Comandos automáticos executados:

```bash
# Status dos containers
docker compose ps

# Logs em tempo real
docker compose logs -f

# Status Cloudflare Tunnel
sudo systemctl status cloudflared

# Ver logs do Cloudflare
sudo journalctl -u cloudflared -f
```

### URLs de Acesso:

- **Superset:** https://bi.bomgado.com.br
- **Airflow:** https://airflow.bomgado.com.br
- **Hop:** https://hop.bomgado.com.br

**Credenciais padrão:**
- Usuário: `admin`
- Senha: `admin123`

⚠️ **Altere as senhas após primeiro login!**

---

## 🔄 Reinstalação ou Atualização

```bash
# Parar containers
docker compose down

# Fazer backup (opcional)
cp .env .env.backup

# Executar instalação novamente
./install.sh --config install.config
```

---

## 🆘 Troubleshooting Rápido

### Erro: "permission denied while trying to connect to the Docker daemon socket"

**Causa:** Usuário não tem permissões Docker ainda.

**Solução 1 - Aguardar instalação completar:**
```bash
# O script usa 'sudo docker' automaticamente durante instalação
# Após concluir, faça logout/login:
exit
ssh -i ~/.ssh/key.pem user@server
cd data-platform

# Agora pode usar docker sem sudo
docker compose ps
```

**Solução 2 - Aplicar permissões imediatamente (alternativa):**
```bash
# Em outra aba do terminal, execute:
newgrp docker

# Ou reinicie o script na nova sessão:
exit
ssh -i ~/.ssh/key.pem user@server
cd data-platform
newgrp docker
./install.sh --auto
```

### Logs da instalação:

```bash
cat install.log
```

### Container não inicia:

```bash
docker compose logs <nome-container>
docker compose restart <nome-container>
```

### Cloudflare Tunnel offline:

```bash
sudo systemctl restart cloudflared
sudo journalctl -u cloudflared -n 50
```

### Refazer instalação do zero:

```bash
# Limpar tudo
docker compose down -v
rm -rf airflow/logs/* superset/data/*

# Reinstalar
./install.sh --config install.config
```

---

## 📊 Comparação de Métodos

| Método | Tempo | Interação | Uso Recomendado |
|--------|-------|-----------|-----------------|
| **--auto** | 15-20 min | Zero | Primeira instalação limpa |
| **--config** | 15-20 min | Mínima | Deploy repetível/produção |
| **Interativo** | 20-30 min | Alta | Quando quer controle total |
| **Manual** | 60-80 min | Máxima | Troubleshooting/customização |

---

## 📚 Documentação Adicional

- **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Guia manual completo (passo a passo)
- **[QUICKSTART.md](QUICKSTART.md)** - Início rápido simplificado
- **[CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)** - Detalhes do Cloudflare
- **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** - Configuração SSO completa
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solução de problemas
- **[SECURITY_BEST_PRACTICES.md](SECURITY_BEST_PRACTICES.md)** - Segurança

---

## 🎯 Próximos Passos Após Instalação

1. ✅ Alterar senhas padrão
2. ✅ Criar usuários personalizados
3. ✅ Configurar conexões de dados (Superset)
4. ✅ Criar DAGs (Airflow)
5. ✅ Desenvolver pipelines (Hop)
6. ✅ Configurar backups automáticos
7. ✅ Habilitar monitoramento

---

**🚀 Com o novo script, você vai do servidor limpo para produção em menos de 20 minutos!**
