# 🤖 Scripts de Automação - Guia de Uso

Este diretório contém scripts inteligentes que automatizam 100% da instalação e validação da plataforma.

---

## 📋 Lista de Scripts

| Script | Propósito | Tempo | Quando Usar |
|--------|-----------|-------|-------------|
| **install.sh** | Instalação completa automatizada | 15-20 min | Instalação inicial ou reinstalação |
| **install.config.example** | Template de configuração | - | Base para criar install.config |
| **validate-installation.sh** | Validação pós-instalação | 1-2 min | Após instalação para verificar status |
| **configure-cloudflare.sh** | Setup Cloudflare Tunnel | 2-3 min | Configurar apenas Cloudflare |
| **fix-sso-config.sh** | Corrigir SSO | 1 min | Quando SSO não funciona |
| **generate_secrets.py** | Gerar chaves de segurança | 30 seg | Quando precisa gerar apenas secrets |

---

## 🚀 install.sh - Instalação Master

### Descrição
Script principal que orquestra toda a instalação do zero. Detecta o sistema, instala dependências, configura tudo e valida a instalação.

### Opções de Uso

#### 1️⃣ Modo Automático (Recomendado para CI/CD)
```bash
chmod +x install.sh
./install.sh --auto
```
**Quando usar:** Servidor limpo, instalação sem interação humana.

#### 2️⃣ Modo com Arquivo de Configuração (Recomendado para Produção)
```bash
# Criar configuração
cp install.config.example install.config
nano install.config  # Editar valores

# Executar
./install.sh --config install.config
```
**Quando usar:** Deploy repetível, múltiplos ambientes (dev/staging/prod).

#### 3️⃣ Modo Interativo
```bash
./install.sh
```
**Quando usar:** Primeira instalação, quer controle de cada etapa.

### O Que o Script Faz

1. ✅ **Verifica Sistema**
   - Detecta Ubuntu/Debian
   - Verifica se não é root
   - Valida pré-requisitos

2. ✅ **Instala Dependências**
   - curl, wget, git, vim, nano
   - python3, pip, jq
   - Ferramentas de rede

3. ✅ **Configura Sistema**
   - Timezone (America/Sao_Paulo)
   - Locale
   - Hostname (opcional)

4. ✅ **Instala Docker**
   - Remove versões antigas
   - Adiciona repositório oficial
   - Instala Docker Engine + Compose
   - Configura permissões

5. ✅ **Gera Secrets**
   - POSTGRES_PASSWORD
   - REDIS_PASSWORD
   - AIRFLOW__CORE__FERNET_KEY
   - AIRFLOW__WEBSERVER__SECRET_KEY
   - SUPERSET_SECRET_KEY

6. ✅ **Cria Estrutura**
   - Diretórios necessários
   - Permissões corretas
   - Arquivos de configuração

7. ✅ **Configura Cloudflare Tunnel** (Opcional)
   - Instala cloudflared
   - Registra tunnel
   - Inicia serviço

8. ✅ **Configura Azure SSO** (Opcional)
   - Cria arquivos de config
   - Atualiza .env
   - Monta volumes

9. ✅ **Deploy Containers**
   - Pull de imagens
   - Inicia todos os services
   - Aguarda inicialização

10. ✅ **Valida Instalação**
    - Testa containers
    - Verifica HTTP
    - Testa conectividade
    - Gera relatório

### Variáveis do install.config

```bash
# Básico
PUBLIC_DOMAIN=bi.bomgado.com.br      # Domínio principal
TIMEZONE=America/Sao_Paulo            # Timezone do servidor
INSTALL_MODE=auto                     # auto ou interactive

# Docker
INSTALL_DOCKER=yes                    # Instalar Docker?
CONFIGURE_DOCKER_PERMISSIONS=yes      # Adicionar user ao grupo?

# Cloudflare Tunnel
SETUP_CLOUDFLARE=yes                  # Configurar Cloudflare?
CLOUDFLARE_TUNNEL_TOKEN=<token>       # Token do tunnel

# Segurança
AUTO_GENERATE_SECRETS=yes             # Gerar secrets automaticamente?

# SSL (apenas sem Cloudflare)
SETUP_SSL=skip                        # skip, selfsigned ou letsencrypt

# Azure SSO (opcional)
SETUP_AZURE_SSO=no                    # Configurar SSO?
AZURE_TENANT_ID=<id>
AZURE_SUPERSET_CLIENT_ID=<id>
AZURE_SUPERSET_CLIENT_SECRET=<secret>
AZURE_AIRFLOW_CLIENT_ID=<id>
AZURE_AIRFLOW_CLIENT_SECRET=<secret>

# Testes
RUN_TESTS=yes                         # Executar testes após instalação?
STARTUP_WAIT_TIME=120                 # Tempo de espera (segundos)
```

### Logs
```bash
# Ver log da instalação
cat install.log

# Acompanhar em tempo real
tail -f install.log
```

---

## ✅ validate-installation.sh - Validação

### Descrição
Script que executa bateria completa de testes para verificar se tudo está funcionando.

### Uso

```bash
chmod +x validate-installation.sh

# Modo resumido
./validate-installation.sh

# Modo detalhado
./validate-installation.sh --detailed
```

### O Que Valida

- ✅ Docker instalado e rodando
- ✅ Docker Compose funcional
- ✅ Arquivo .env configurado
- ✅ Secrets gerados
- ✅ Estrutura de diretórios
- ✅ Permissões corretas
- ✅ Containers rodando
- ✅ Serviços HTTP respondendo
- ✅ PostgreSQL conectável
- ✅ Redis acessível
- ✅ Cloudflare Tunnel ativo
- ✅ HTTPS funcionando
- ✅ Azure SSO configurado

### Output
```
╔═══════════════════════════════════════════════════════════════════╗
║          ✓  VALIDAÇÃO DA INSTALAÇÃO - PLATAFORMA DE DADOS        ║
╚═══════════════════════════════════════════════════════════════════╝

══════════════════════════════════════════════════════════
  Docker e Docker Compose
══════════════════════════════════════════════════════════

✓ Docker instalado
   → Versão: 24.0.7
✓ Docker daemon rodando
✓ Docker Compose instalado
   → Versão: 2.23.0
✓ Usuário no grupo docker

[... mais testes ...]

══════════════════════════════════════════════════════════
  Resumo da Validação
══════════════════════════════════════════════════════════

Testes Passaram:   45
Testes Falharam:   0
Avisos:            2
Total de Testes:   47

Taxa de Sucesso: 95% ✓

╔═══════════════════════════════════════════════════════════════════╗
║  ✓✓✓  INSTALAÇÃO PERFEITA - TUDO FUNCIONANDO CORRETAMENTE!  ✓✓✓ ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## ☁️ configure-cloudflare.sh - Setup Cloudflare Tunnel

### Descrição
Instala e configura apenas o Cloudflare Tunnel (útil se já tem Docker instalado).

### Uso
```bash
chmod +x configure-cloudflare.sh
./configure-cloudflare.sh <seu-token-aqui>
```

### Como Obter o Token
1. https://dash.cloudflare.com
2. Zero Trust → Tunnels → Create tunnel
3. Nome: bi-bomgado-data-platform
4. Copiar token
5. Configurar Public Hostnames:
   - bi.bomgado.com.br → localhost:80
   - airflow.bomgado.com.br → localhost:8080
   - hop.bomgado.com.br → localhost:8081

---

## 🔐 fix-sso-config.sh - Corrigir SSO

### Descrição
Cria arquivos de configuração SSO e atualiza containers.

### Uso
```bash
chmod +x fix-sso-config.sh
./fix-sso-config.sh
```

### Pré-requisitos
Variáveis no .env:
- AZURE_TENANT_ID
- AZURE_SUPERSET_CLIENT_ID
- AZURE_SUPERSET_CLIENT_SECRET
- AZURE_AIRFLOW_CLIENT_ID
- AZURE_AIRFLOW_CLIENT_SECRET

### O Que Faz
1. Verifica .env
2. Cria airflow/config/webserver_config.py
3. Cria superset/config/superset_config.py
4. Reinicia containers
5. Verifica logs

---

## 🔑 generate_secrets.py - Gerar Secrets

### Descrição
Gera chaves criptográficas fortes.

### Uso
```bash
python3 generate_secrets.py
```

### Output
```
Secrets Gerados:

POSTGRES_PASSWORD=AbCd1234EfGh5678IjKl
REDIS_PASSWORD=MnOp9012QrSt3456UvWx
AIRFLOW__CORE__FERNET_KEY=YourFernetKeyHere==
AIRFLOW__WEBSERVER__SECRET_KEY=YourWebserverSecretKeyHere
SUPERSET_SECRET_KEY=YourSupersetSecretKeyHere

Copie estes valores para o arquivo .env
```

---

## 📊 Fluxo de Trabalho Recomendado

### Instalação Nova (Servidor Limpo)
```bash
# 1. Clonar repositório
git clone <url> data-platform
cd data-platform

# 2. Criar configuração
cp install.config.example install.config
nano install.config

# 3. Executar instalação
chmod +x install.sh
./install.sh --config install.config

# 4. Validar
chmod +x validate-installation.sh
./validate-installation.sh --detailed
```

### Troubleshooting
```bash
# Validar instalação
./validate-installation.sh --detailed

# Ver logs
cat install.log
docker compose logs -f

# Corrigir SSO
./fix-sso-config.sh

# Reiniciar tudo
docker compose down
docker compose up -d
```

### Atualização
```bash
# Pull mudanças
git pull

# Recriar containers
docker compose down
docker compose up -d --build

# Validar
./validate-installation.sh
```

---

## 🎯 Comparação: Manual vs Automatizado

| Tarefa | Manual | Automatizado |
|--------|--------|--------------|
| **Instalar dependências** | 5-10 min | ✅ Automático |
| **Instalar Docker** | 10-15 min | ✅ Automático |
| **Gerar secrets** | 5 min | ✅ Automático |
| **Criar .env** | 5 min | ✅ Automático |
| **Criar diretórios** | 2 min | ✅ Automático |
| **Permissões** | 3 min | ✅ Automático |
| **Cloudflare Tunnel** | 10 min | ✅ Automático |
| **Deploy containers** | 10 min | ✅ Automático |
| **Configurar SSO** | 15 min | ✅ Automático |
| **Validar instalação** | 10 min | ✅ Automático |
| **TOTAL** | **60-80 min** | **15-20 min** |

---

## ⚠️ Troubleshooting dos Scripts

### Erro: "Permission denied"
```bash
chmod +x *.sh
```

### Erro: "Docker não encontrado" após instalação
```bash
# Aplicar permissões do grupo
newgrp docker

# OU fazer logout/login
```

### Cloudflare Tunnel não inicia
```bash
# Ver logs
sudo journalctl -u cloudflared -n 50

# Verificar token
sudo systemctl stop cloudflared
sudo cloudflared service uninstall
./configure-cloudflare.sh <novo-token>
```

### Containers não sobem
```bash
# Ver logs
docker compose logs

# Verificar recursos
docker stats

# Recriar do zero
docker compose down -v
./install.sh --config install.config
```

---

## 📚 Documentação Relacionada

- **[AUTOMATED_INSTALL.md](AUTOMATED_INSTALL.md)** - Guia completo de instalação automatizada
- **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Guia manual passo a passo
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solução de problemas
- **[SECURITY_BEST_PRACTICES.md](SECURITY_BEST_PRACTICES.md)** - Boas práticas

---

**🤖 Automatize tudo. Elimine erros. Ganhe tempo.**
