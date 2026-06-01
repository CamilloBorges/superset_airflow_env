# 📚 Índice de Documentação

Guia completo de toda a documentação disponível neste projeto.

---

## 🎯 Início Rápido

| Documento | Quando Usar | Tempo Estimado |
|-----------|-------------|----------------|
| **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** | ⭐ **Instalação completa do zero** (Ubuntu limpo → SSO) | 🕐 60-80 minutos |
| **[QUICKSTART.md](QUICKSTART.md)** | Você já tem Docker instalado e quer começar rapidamente | ⚡ 5 minutos |
| **[CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)** | Configurar acesso seguro via Cloudflare (recomendado) | ☁️ 15 minutos |
| **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** | Ubuntu Server zerado (sem Cloudflare Tunnel) | 🐧 30-60 minutos |
| **[AZURE_SETUP.md](AZURE_SETUP.md)** | Azure VM (somente se NÃO usar Cloudflare Tunnel) | 🌩️ 10 minutos |
| **[HTTPS_SETUP.md](HTTPS_SETUP.md)** | SSL/TLS manual (somente se NÃO usar Cloudflare Tunnel) | 🔒 15-30 minutos |
| **[AZURE_SSO_RESUMO.md](AZURE_SSO_RESUMO.md)** | Resumo executivo do SSO com Azure Entra ID | 🔐 5 minutos leitura |
| **[CHECKLIST.md](CHECKLIST.md)** | Verificar se todos os passos foram executados corretamente | ✅ 5 minutos |

---

## 📖 Documentação Principal

| Documento | Descrição | Para Quem |
|-----------|-----------|-----------|
| **[README.md](README.md)** | Documentação principal com guia completo de instalação e uso | 📘 Todos os usuários |
| **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** | Estrutura visual detalhada do projeto e organização de arquivos | 🗂️ Desenvolvedores e administradores |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Solução de problemas comuns com diagnóstico e correções | 🔧 Quando algo não funciona |

---

## 🛠️ Guias Técnicos Específicos

| Documento | Foco | Público |
|-----------|------|---------|
| **[CLOUDFLARE_TUNNEL_SETUP.md](CLOUDFLARE_TUNNEL_SETUP.md)** | Configurar Cloudflare Tunnel (acesso seguro sem expor portas) | ☁️ Recomendado para produção |
| **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** | Guia completo do Apache Hop: projetos, pipelines, workflows | 🔄 Engenheiros de Dados |
| **[AZURE_SETUP.md](AZURE_SETUP.md)** | Configuração de NSG no Azure (somente sem Cloudflare Tunnel) | 🌩️ DevOps Azure |
| **[HTTPS_SETUP.md](HTTPS_SETUP.md)** | SSL/TLS manual: Let's Encrypt, auto-assinado (sem Cloudflare) | 🔒 DevOps / SysAdmin |
| **[AZURE_ENTRA_SSO.md](AZURE_ENTRA_SSO.md)** | Configurar Single Sign-On com Azure Entra ID (OAuth2) | 🔐 Administradores / DevOps |
| **[docker-compose.yml](docker-compose.yml)** | Definição da infraestrutura (comentado) | 🐋 DevOps e SREs |
| **[.env.example](.env.example)** | Template de variáveis de ambiente com documentação | ⚙️ Administradores |

---

## 🚀 Scripts de Automação

| Script | Plataforma | Descrição |
|--------|-----------|-----------|
| **[configure-cloudflare.sh](configure-cloudflare.sh)** | Linux | Instalação automatizada do Cloudflare Tunnel |
| **[quick-start.sh](quick-start.sh)** | Linux/Mac | Script automatizado de inicialização |
| **[quick-start.ps1](quick-start.ps1)** | Windows | Script automatizado de inicialização |
| **[generate_secrets.py](generate_secrets.py)** | Todos | Gerador de chaves de segurança |
| **[Makefile](Makefile)** | Linux/Mac | Comandos úteis (make up, make logs, etc) |

---

## 📊 Fluxo de Leitura Recomendado

### 🆕 Primeira Vez? (Servidor Zerado) - **RECOMENDADO**

```
1. INSTALLATION_GUIDE.md        → ⭐ Guia completo unificado (60-80 min)
   ├── Fase 1: Preparar Ubuntu
   ├── Fase 2: Instalar Docker
   ├── Fase 3: Configurar Cloudflare Tunnel
   ├── Fase 4: Deploy da Plataforma
   └── Fase 5: Configurar Azure Entra SSO (opcional)

2. CHECKLIST.md                 → Verificar instalação
3. hop/HOP_GUIDE.md             → Criar pipelines ETL
```

### ☁️ Com Cloudflare Tunnel (Produção)

```
1. CLOUDFLARE_TUNNEL_SETUP.md   → Configurar tunnel
2. QUICKSTART.md                → Deploy rápido
3. AZURE_ENTRA_SSO.md           → (Opcional) SSO
4. CHECKLIST.md                 → Verificar
```

### 🌩️ Azure sem Cloudflare (Direto via IP)

```
1. UBUNTU_SETUP.md              → Setup básico do Ubuntu
2. AZURE_SETUP.md               → Configurar NSG e portas
3. HTTPS_SETUP.md               → Configurar SSL/TLS
4. TROUBLESHOOTING.md           → Se houver problemas
```

### ⚡ Já Tem Docker? (Setup Rápido)

```
1. QUICKSTART.md                → Iniciar em 5 minutos
2. CLOUDFLARE_TUNNEL_SETUP.md   → (Opcional) Cloudflare
3. CHECKLIST.md                 → Verificar instalação
4. hop/HOP_GUIDE.md             → Criar pipelines
```

### 🔧 Manutenção e Operação

```
1. TROUBLESHOOTING.md   → Quando há problemas
2. Makefile             → Comandos do dia-a-dia
3. docker-compose.yml   → Ajustar configurações
```

### 👨‍💻 Desenvolvimento

```
1. PROJECT_STRUCTURE.md → Entender organização
2. .env.example         → Configurar variáveis
3. airflow/dags/        → Criar DAGs
4. hop/HOP_GUIDE.md     → Criar pipelines Hop
```

---

## 🎓 Por Nível de Experiência

### 🟢 Iniciante

1. **[QUICKSTART.md](QUICKSTART.md)** ou **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** (dependendo do cenário)
2. **[README.md](README.md)** - Seções: Guia de Inicialização, Operações Comuns
3. **[CHECKLIST.md](CHECKLIST.md)** - Verificar tudo
4. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Quando travar

### 🟡 Intermediário

1. **[README.md](README.md)** - Completo
2. **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Entender organização
3. **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** - Criar pipelines
4. **[docker-compose.yml](docker-compose.yml)** - Customizar

### 🔴 Avançado

1. **[docker-compose.yml](docker-compose.yml)** - Infraestrutura
2. **[.env.example](.env.example)** - Todas as variáveis
3. **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Arquitetura
4. **[Makefile](Makefile)** - Automação
5. Código-fonte das DAGs e configurações

---

## 🗂️ Organização por Tópico

### 🐳 Docker e Infraestrutura

- [docker-compose.yml](docker-compose.yml) - Definição completa
- [README.md](README.md) - Seção "Configuração do Executor"
- [UBUNTU_SETUP.md](UBUNTU_SETUP.md) - Instalação do Docker
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problemas com containers

### 🔐 Segurança e Configuração

- [.env.example](.env.example) - Template de variáveis
- [generate_secrets.py](generate_secrets.py) - Gerar chaves
- [README.md](README.md) - Seção "Segurança"
- [UBUNTU_SETUP.md](UBUNTU_SETUP.md) - Passo 6: Configurar Variáveis

### ⚙️ Apache Airflow

- [README.md](README.md) - Seção "Integração Airflow + Hop"
- [airflow/dags/hop_etl_pipeline_example.py](airflow/dags/hop_etl_pipeline_example.py) - DAG de exemplo
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Seção "Problemas Específicos do Airflow"

### 📊 Apache Superset

- [superset/config/superset_config.py](superset/config/superset_config.py) - Configuração customizada
- [README.md](README.md) - Seção "Conexões no Superset"
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Seção "Problemas Específicos do Superset"

### 🔄 Apache Hop (ETL)

- **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** - Guia completo ⭐
- [README.md](README.md) - Seção "Integração Airflow + Hop"
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Seção "Problemas Específicos do Hop"

### 🗄️ PostgreSQL e Redis

- [postgres/init-scripts/01-init-databases.sh](postgres/init-scripts/01-init-databases.sh) - Inicialização
- [docker-compose.yml](docker-compose.yml) - Configuração
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Seção "Problemas com Banco de Dados"

---

## 🔍 Busca Rápida

### "Como faço para..."

| Pergunta | Documento | Seção |
|----------|-----------|-------|
| ...instalar do zero? | [UBUNTU_SETUP.md](UBUNTU_SETUP.md) | Todo |
| ...configurar variáveis de ambiente? | [README.md](README.md) | Passo 2 |
| ...gerar chaves de segurança? | [QUICKSTART.md](QUICKSTART.md) | Passo 2 |
| ...criar pipeline Hop? | [hop/HOP_GUIDE.md](hop/HOP_GUIDE.md) | Exemplo Prático |
| ...integrar Hop com Airflow? | [README.md](README.md) | Integração Airflow + Hop |
| ...resolver erro X? | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Buscar erro |
| ...parar/iniciar serviços? | [README.md](README.md) | Operações Comuns |
| ...acessar logs? | [README.md](README.md) | Visualizar Logs |
| ...resetar ambiente? | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Comandos Úteis |

---

## 📞 Ainda Perdido?

1. **Instalação do zero?** → [UBUNTU_SETUP.md](UBUNTU_SETUP.md)
2. **Setup rápido?** → [QUICKSTART.md](QUICKSTART.md)
3. **Deu erro?** → [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. **Quer visão geral?** → [README.md](README.md)
5. **Criar pipelines?** → [hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)

---

## 📥 Download Rápido

```bash
# Clonar repositório
git clone <url-repositorio>

# Entrar no diretório
cd superset_airflow_env

# Visualizar documentação
ls -la *.md
```

---

**Toda documentação está interligada!** Use os links internos para navegar facilmente entre os documentos. 🔗
