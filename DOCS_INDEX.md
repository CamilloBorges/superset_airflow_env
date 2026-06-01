# 📚 Índice de Documentação

Guia completo de toda a documentação disponível neste projeto.

---

## 🎯 Início Rápido

| Documento | Quando Usar | Tempo Estimado |
|-----------|-------------|----------------|
| **[QUICKSTART.md](QUICKSTART.md)** | Você já tem Docker instalado e quer começar rapidamente | ⚡ 5 minutos |
| **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** | Você tem Ubuntu Server zerado e precisa instalar tudo do zero | 🐧 30-60 minutos |
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
| **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** | Guia completo do Apache Hop: projetos, pipelines, workflows | 🔄 Engenheiros de Dados |
| **[docker-compose.yml](docker-compose.yml)** | Definição da infraestrutura (comentado) | 🐋 DevOps e SREs |
| **[.env.example](.env.example)** | Template de variáveis de ambiente com documentação | ⚙️ Administradores |

---

## 🚀 Scripts de Automação

| Script | Plataforma | Descrição |
|--------|-----------|-----------|
| **[quick-start.sh](quick-start.sh)** | Linux/Mac | Script automatizado de inicialização |
| **[quick-start.ps1](quick-start.ps1)** | Windows | Script automatizado de inicialização |
| **[generate_secrets.py](generate_secrets.py)** | Todos | Gerador de chaves de segurança |
| **[Makefile](Makefile)** | Linux/Mac | Comandos úteis (make up, make logs, etc) |

---

## 📊 Fluxo de Leitura Recomendado

### 🆕 Primeira Vez? (Servidor Zerado)

```
1. UBUNTU_SETUP.md      → Instalar tudo do zero
2. CHECKLIST.md         → Verificar instalação
3. README.md            → Entender o ambiente
4. hop/HOP_GUIDE.md     → Criar pipelines ETL
```

### ⚡ Já Tem Docker? (Setup Rápido)

```
1. QUICKSTART.md        → Iniciar em 5 minutos
2. CHECKLIST.md         → Verificar instalação
3. hop/HOP_GUIDE.md     → Criar pipelines
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
