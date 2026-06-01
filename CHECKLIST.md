# 📋 Checklist de Instalação Rápida

Use este checklist para garantir que todos os passos foram executados corretamente.

---

## ✅ Checklist - Ubuntu Server do Zero

### 1️⃣ Sistema Operacional
- [ ] Ubuntu Server 20.04 LTS ou superior instalado
- [ ] Sistema atualizado (`sudo apt update && sudo apt upgrade -y`)
- [ ] Pacotes essenciais instalados (`curl`, `git`, `vim`, `wget`)

### 2️⃣ Docker
- [ ] Docker instalado e rodando
- [ ] Docker Compose instalado
- [ ] Usuário adicionado ao grupo docker (opcional: `sudo usermod -aG docker $USER`)
- [ ] Teste: `docker --version` funciona
- [ ] Teste: `docker compose version` funciona
- [ ] Teste: `docker run hello-world` funciona

### 3️⃣ Python (opcional, para gerar chaves)
- [ ] Python 3 instalado (`python3 --version`)
- [ ] pip instalado (`pip3 --version`)
- [ ] Biblioteca cryptography instalada (`pip3 install cryptography`)

### 4️⃣ Repositório
- [ ] Repositório clonado ou arquivos transferidos
- [ ] Navegado para o diretório do projeto (`cd superset_airflow_env`)

### 5️⃣ Variáveis de Ambiente
- [ ] Arquivo `.env.example` copiado para `.env`
- [ ] Chaves de segurança geradas:
  - [ ] `POSTGRES_PASSWORD`
  - [ ] `REDIS_PASSWORD`
  - [ ] `AIRFLOW__CORE__FERNET_KEY`
  - [ ] `AIRFLOW__WEBSERVER__SECRET_KEY`
  - [ ] `SUPERSET_SECRET_KEY`
- [ ] Arquivo `.env` editado com as chaves geradas
- [ ] Arquivo `.env` salvo

### 6️⃣ Permissões (Linux/Mac)
- [ ] Scripts com permissão de execução: `chmod +x quick-start.sh`
- [ ] Scripts de init do Postgres: `chmod +x postgres/init-scripts/*.sh`
- [ ] Diretórios criados: `airflow/`, `superset/`, `hop/`, etc.
- [ ] Permissões ajustadas: `chmod -R 755 airflow/`
- [ ] Logs do Airflow com permissão total: `chmod -R 777 airflow/logs`
- [ ] Proprietário do Airflow ajustado: `sudo chown -R 50000:0 airflow/`

### 7️⃣ Inicialização
- [ ] Imagens Docker baixadas (`docker compose pull`)
- [ ] Containers iniciados (`docker compose up -d` ou `./quick-start.sh`)
- [ ] Aguardado 2-5 minutos para inicialização completa

### 8️⃣ Verificação
- [ ] Comando `docker compose ps` mostra todos containers rodando
- [ ] Logs sem erros críticos: `docker compose logs`
- [ ] Container postgres está `healthy`
- [ ] Container redis está `healthy`
- [ ] Container airflow-webserver está `healthy`
- [ ] Container superset está `healthy`

### 9️⃣ Acesso às Interfaces
- [ ] Airflow acessível: http://localhost:8080 ou http://IP-SERVIDOR:8080
- [ ] Login no Airflow funciona (admin/admin123)
- [ ] Superset acessível: http://localhost:8088 ou http://IP-SERVIDOR:8088
- [ ] Login no Superset funciona (admin/admin123)
- [ ] Hop acessível: http://localhost:8081 ou http://IP-SERVIDOR:8081
- [ ] Login no Hop funciona (cluster/cluster)

### 🔟 Segurança
- [ ] Senhas padrão alteradas:
  - [ ] Senha admin do Airflow
  - [ ] Senha admin do Superset
  - [ ] Senha cluster do Hop (se necessário)
- [ ] Arquivo `.env` NÃO foi commitado no Git
- [ ] Firewall configurado (se acesso remoto):
  - [ ] Porta 8080 (Airflow)
  - [ ] Porta 8088 (Superset)
  - [ ] Porta 8081 (Hop)

---

## ✅ Checklist - Windows

### 1️⃣ Docker Desktop
- [ ] Docker Desktop instalado
- [ ] Docker Desktop rodando
- [ ] WSL2 habilitado (se aplicável)
- [ ] Memória alocada: mínimo 8GB (Settings → Resources)

### 2️⃣ Python (opcional)
- [ ] Python 3 instalado
- [ ] Biblioteca cryptography instalada ou usar Docker para gerar chaves

### 3️⃣ Repositório
- [ ] Repositório clonado
- [ ] PowerShell aberto no diretório do projeto

### 4️⃣ Variáveis de Ambiente
- [ ] `.env` criado a partir de `.env.example`
- [ ] Chaves geradas (usar `generate_secrets.py` ou Docker)
- [ ] `.env` editado com chaves

### 5️⃣ Inicialização
- [ ] Executado `.\quick-start.ps1` ou `docker compose up -d`
- [ ] Aguardado inicialização (2-5 minutos)

### 6️⃣ Verificação
- [ ] `docker compose ps` mostra containers rodando
- [ ] Interfaces web acessíveis no navegador
- [ ] Login funciona em todos os serviços

### 7️⃣ Segurança
- [ ] Senhas padrão alteradas
- [ ] `.env` não commitado no Git

---

## 🆘 Problemas Comuns

### ❌ Docker não está instalado
**Solução**: Consulte [UBUNTU_SETUP.md](UBUNTU_SETUP.md) para instalação completa

### ❌ Permission denied ao executar scripts
**Solução**: 
```bash
chmod +x quick-start.sh
chmod +x postgres/init-scripts/*.sh
```

### ❌ Containers não iniciam
**Solução**: 
```bash
docker compose logs postgres
docker compose logs redis
```
Verifique se portas estão livres e se há memória suficiente

### ❌ Erro "Fernet key invalid"
**Solução**: Gere nova chave com:
```bash
docker run --rm python:3.11-slim sh -c "pip install cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
```

### ❌ Airflow logs com erro de permissão
**Solução** (Linux):
```bash
sudo chown -R 50000:0 airflow/
chmod -R 777 airflow/logs
```

---

## 📚 Documentação Completa

- [README.md](README.md) - Documentação principal
- [UBUNTU_SETUP.md](UBUNTU_SETUP.md) - Setup completo Ubuntu Server
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Solução de problemas
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Estrutura do projeto
- [hop/HOP_GUIDE.md](hop/HOP_GUIDE.md) - Guia do Apache Hop

---

## 🎯 Comandos Rápidos

```bash
# Verificar status
docker compose ps

# Ver logs
docker compose logs -f

# Reiniciar tudo
docker compose restart

# Parar tudo
docker compose stop

# Iniciar tudo
docker compose start

# Destruir tudo (CUIDADO!)
docker compose down -v
```

---

**Todos os itens marcados? Parabéns! 🎉**

Seu ambiente de dados está pronto para uso!
