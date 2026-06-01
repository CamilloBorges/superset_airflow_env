# Guia Completo de Instalação - Ubuntu Server

Este guia assume que você tem um **Ubuntu Server** recém-instalado e vai configurar todo o ambiente do zero.

## 📋 Pré-requisitos

- Ubuntu Server 20.04 LTS ou superior
- Acesso root ou usuário com privilégios sudo
- Conexão com a internet
- Pelo menos 8GB de RAM
- 20GB de espaço em disco livre

---

## 🚀 Passo 1: Atualizar o Sistema

```bash
# Atualizar lista de pacotes
sudo apt update

# Atualizar pacotes instalados
sudo apt upgrade -y

# Instalar pacotes essenciais
sudo apt install -y curl git vim wget software-properties-common
```

---

## 🐋 Passo 2: Instalar Docker

### 2.1 Remover versões antigas (se existirem)

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
```

### 2.2 Instalar Docker Engine

```bash
# Adicionar repositório oficial do Docker
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Adicionar chave GPG oficial do Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Configurar repositório
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualizar e instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 2.3 Verificar instalação do Docker

```bash
# Verificar versão
sudo docker --version
sudo docker compose version

# Testar Docker
sudo docker run hello-world
```

### 2.4 Adicionar usuário ao grupo Docker (opcional, mas recomendado)

```bash
# Adicionar usuário atual ao grupo docker
sudo usermod -aG docker $USER

# Aplicar mudanças (ou faça logout/login)
newgrp docker

# Agora você pode executar docker sem sudo
docker --version
```

---

## 📦 Passo 3: Instalar Python 3 (para scripts auxiliares)

```bash
# Instalar Python 3 e pip
sudo apt install -y python3 python3-pip python3-venv

# Verificar instalação
python3 --version
pip3 --version

# Instalar biblioteca cryptography (para gerar chaves)
pip3 install cryptography
```

---

## 🔧 Passo 4: Configurar Git (se for usar repositório)

```bash
# Configurar usuário Git
git config --global user.name "Seu Nome"
git config --global user.email "seu-email@exemplo.com"

# Verificar configuração
git config --list
```

---

## 📂 Passo 5: Clonar o Repositório do Projeto

### Opção A: Clonar de repositório Git

```bash
# Navegar para diretório home
cd ~

# Clonar repositório
git clone <url-do-seu-repositorio> superset_airflow_env

# Entrar no diretório
cd superset_airflow_env
```

### Opção B: Criar estrutura manualmente

```bash
# Criar diretório do projeto
mkdir -p ~/superset_airflow_env
cd ~/superset_airflow_env

# Baixar os arquivos do projeto
# (transfira os arquivos via SCP, SFTP ou outro método)
```

---

## 🔐 Passo 6: Configurar Variáveis de Ambiente

### 6.1 Copiar arquivo de exemplo

```bash
cp .env.example .env
```

### 6.2 Gerar chaves de segurança

**Opção 1: Usando Python local**

```bash
python3 generate_secrets.py
```

**Opção 2: Usando Docker (se Python não tiver cryptography)**

```bash
docker run --rm python:3.11-slim sh -c "pip install cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
```

### 6.3 Editar arquivo .env

```bash
# Editar com seu editor preferido
nano .env
# ou
vim .env
```

Cole as chaves geradas nas respectivas variáveis:
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `AIRFLOW__CORE__FERNET_KEY`
- `AIRFLOW__WEBSERVER__SECRET_KEY`
- `SUPERSET_SECRET_KEY`

Salve e feche o arquivo (Ctrl+X, Y, Enter no nano).

---

## 🔑 Passo 7: Ajustar Permissões dos Scripts

```bash
# Dar permissão de execução aos scripts
chmod +x quick-start.sh
chmod +x postgres/init-scripts/*.sh

# Verificar permissões
ls -la quick-start.sh
ls -la postgres/init-scripts/
```

---

## 📁 Passo 8: Criar Diretórios e Ajustar Permissões

```bash
# Criar diretórios necessários
mkdir -p airflow/{logs,dags,plugins,config}
mkdir -p superset/{config,data}
mkdir -p hop/{config,projects,metadata}
mkdir -p postgres/init-scripts
mkdir -p shared/data

# Ajustar permissões para o Airflow
# O UID padrão do Airflow é 50000
sudo chown -R 50000:0 airflow/
chmod -R 755 airflow/
chmod -R 777 airflow/logs

# Permissões para outros diretórios
chmod -R 755 superset hop postgres shared
```

---

## 🚀 Passo 9: Inicializar o Ambiente

### Opção A: Usando script automatizado (recomendado)

```bash
./quick-start.sh
```

### Opção B: Manualmente

```bash
# Baixar imagens Docker
docker compose pull

# Iniciar todos os serviços
docker compose up -d

# Aguardar serviços iniciarem (pode levar 2-5 minutos)
sleep 60

# Verificar status
docker compose ps
```

---

## 🔍 Passo 10: Verificar Instalação

### 10.1 Verificar containers rodando

```bash
docker compose ps
```

Todos os serviços devem estar `healthy` ou `running`.

### 10.2 Verificar logs

```bash
# Ver logs de todos os serviços
docker compose logs

# Ver logs de serviço específico
docker compose logs -f airflow-webserver
```

### 10.3 Testar acesso às interfaces

```bash
# Testar Airflow
curl -I http://localhost:8080

# Testar Superset
curl -I http://localhost:8088

# Testar Hop
curl -I http://localhost:8081
```

---

## 🌐 Passo 11: Acessar de Máquina Remota (Opcional)

Se o servidor está em uma máquina remota e você quer acessar as interfaces de outro computador:

### Opção A: SSH Tunnel (mais seguro)

No seu computador local:

```bash
# Túnel para Airflow
ssh -L 8080:localhost:8080 usuario@ip-do-servidor

# Túnel para Superset
ssh -L 8088:localhost:8088 usuario@ip-do-servidor

# Túnel para Hop
ssh -L 8081:localhost:8081 usuario@ip-do-servidor
```

Depois acesse `http://localhost:8080`, etc.

### Opção B: Configurar Firewall (menos seguro)

```bash
# Permitir portas no firewall (UFW)
sudo ufw allow 8080/tcp  # Airflow
sudo ufw allow 8088/tcp  # Superset
sudo ufw allow 8081/tcp  # Hop

# Verificar status
sudo ufw status
```

Acesse via: `http://IP-DO-SERVIDOR:8080`, etc.

---

## 📊 Credenciais Padrão

| Serviço | URL | Usuário | Senha |
|---------|-----|---------|-------|
| **Airflow** | http://localhost:8080 | admin | admin123 |
| **Superset** | http://localhost:8088 | admin | admin123 |
| **Hop** | http://localhost:8081 | cluster | cluster |

⚠️ **IMPORTANTE**: Altere as senhas padrão após o primeiro login!

---

## 🔧 Comandos Úteis de Manutenção

```bash
# Ver status dos containers
docker compose ps

# Ver logs em tempo real
docker compose logs -f

# Reiniciar todos os serviços
docker compose restart

# Parar todos os serviços
docker compose stop

# Iniciar serviços parados
docker compose start

# Parar e remover containers
docker compose down

# Parar e remover containers + volumes (CUIDADO: apaga dados!)
docker compose down -v

# Atualizar imagens Docker
docker compose pull
docker compose up -d
```

---

## 🔄 Configurar Inicialização Automática

Para que os containers iniciem automaticamente quando o servidor reiniciar:

### Opção 1: Habilitar Docker para iniciar com o sistema

```bash
sudo systemctl enable docker
```

### Opção 2: Criar serviço systemd

Crie o arquivo `/etc/systemd/system/data-platform.service`:

```bash
sudo nano /etc/systemd/system/data-platform.service
```

Cole o conteúdo:

```ini
[Unit]
Description=Data Platform - Airflow, Superset, Hop
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/SEU_USUARIO/superset_airflow_env
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Substitua `SEU_USUARIO` pelo seu usuário real.

Habilite o serviço:

```bash
sudo systemctl daemon-reload
sudo systemctl enable data-platform.service
sudo systemctl start data-platform.service

# Verificar status
sudo systemctl status data-platform.service
```

---

## 📈 Monitoramento de Recursos

```bash
# Ver uso de CPU e memória dos containers
docker stats

# Ver espaço em disco usado pelo Docker
docker system df

# Ver volumes criados
docker volume ls
```

---

## 🧹 Limpeza e Manutenção

### Limpar logs antigos do Airflow

```bash
# Acessar container do Airflow
docker exec -it airflow-scheduler bash

# Limpar logs de mais de 30 dias
airflow db clean --clean-before-timestamp $(date -d '30 days ago' +%Y-%m-%d) --yes

# Sair do container
exit
```

### Limpar recursos não utilizados do Docker

```bash
# Limpar containers parados, redes não usadas, imagens pendentes
docker system prune

# Limpar tudo incluindo volumes (CUIDADO!)
docker system prune -a --volumes
```

---

## 🐛 Troubleshooting

### Problema: "Permission denied" ao executar scripts

```bash
chmod +x quick-start.sh
chmod +x postgres/init-scripts/*.sh
```

### Problema: "Cannot connect to Docker daemon"

```bash
# Verificar se Docker está rodando
sudo systemctl status docker

# Iniciar Docker
sudo systemctl start docker

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

### Problema: Falta de memória

```bash
# Verificar memória disponível
free -h

# Ver uso de memória dos containers
docker stats

# Considere aumentar a RAM do servidor ou reduzir paralelismo
# Edite .env e ajuste:
# AIRFLOW__CORE__PARALLELISM=16
```

### Problema: Porta já em uso

```bash
# Verificar o que está usando a porta
sudo lsof -i :8080

# Parar processo (substitua PID)
sudo kill -9 PID

# Ou altere a porta no .env
```

---

## 📚 Referências

- [Documentação do Docker](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Apache Airflow](https://airflow.apache.org/docs/)
- [Apache Superset](https://superset.apache.org/docs/)
- [Apache Hop](https://hop.apache.org/manual/)

---

## ✅ Checklist Completo

- [ ] Ubuntu Server atualizado
- [ ] Docker e Docker Compose instalados
- [ ] Python 3 instalado
- [ ] Repositório clonado ou arquivos transferidos
- [ ] Arquivo `.env` configurado com chaves geradas
- [ ] Permissões de scripts ajustadas (`chmod +x`)
- [ ] Diretórios criados com permissões corretas
- [ ] Serviços iniciados com `docker compose up -d`
- [ ] Interfaces web acessíveis
- [ ] Senhas padrão alteradas
- [ ] Firewall configurado (se acesso remoto)
- [ ] Inicialização automática configurada (opcional)

---

**Ambiente pronto para produção!** 🚀

Se encontrar problemas, consulte o arquivo [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
