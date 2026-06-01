# Troubleshooting Guide - Solução de Problemas Comuns

## 📋 Índice

- [Problemas de Inicialização](#problemas-de-inicialização)
- [Problemas de Rede e Conectividade](#problemas-de-rede-e-conectividade)
- [Problemas de Permissões](#problemas-de-permissões)
- [Problemas de Performance](#problemas-de-performance)
- [Problemas Específicos do Airflow](#problemas-específicos-do-airflow)
- [Problemas Específicos do Superset](#problemas-específicos-do-superset)
- [Problemas Específicos do Hop](#problemas-específicos-do-hop)
- [Problemas com Banco de Dados](#problemas-com-banco-de-dados)

---

## Problemas de Inicialização

### ❌ Containers não inicializam

**Sintoma:**
```
Error: Container xxx is unhealthy
```

**Diagnóstico:**
```bash
# Ver logs do container específico
docker compose logs postgres
docker compose logs redis
docker compose logs airflow-init

# Ver todos os logs
docker compose logs
```

**Soluções:**
1. Verificar se as portas não estão em uso:
   ```bash
   # Windows
   netstat -ano | findstr :8080
   netstat -ano | findstr :5432
   
   # Linux/Mac
   lsof -i :8080
   lsof -i :5432
   ```

2. Alterar portas no arquivo `.env`:
   ```env
   AIRFLOW_EXTERNAL_PORT=8081
   POSTGRES_EXTERNAL_PORT=5433
   ```

3. Aumentar timeout dos healthchecks no `docker-compose.yml`

---

### ❌ Erro "Port already in use"

**Solução:**

**Opção 1 - Alterar porta:**
```bash
# Editar .env
AIRFLOW_EXTERNAL_PORT=8081
SUPERSET_EXTERNAL_PORT=8089
```

**Opção 2 - Parar processo que está usando a porta (Windows):**
```powershell
# Encontrar PID
netstat -ano | findstr :8080

# Matar processo (substitua PID_AQUI pelo número encontrado)
taskkill /PID PID_AQUI /F
```

**Opção 3 - Parar processo (Linux/Mac):**
```bash
# Encontrar e matar processo
lsof -ti:8080 | xargs kill -9
```

---

### ❌ "Cannot connect to Docker daemon"

**Sintoma:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solução:**
1. Verificar se Docker Desktop está rodando
2. No Windows: Reiniciar o Docker Desktop
3. No Linux: Iniciar o serviço Docker:
   ```bash
   sudo systemctl start docker
   ```

---

## Problemas de Rede e Conectividade

### ❌ Serviços não conseguem se comunicar

**Sintoma:**
- Airflow não consegue conectar ao PostgreSQL
- Superset não consegue conectar ao Redis

**Diagnóstico:**
```bash
# Verificar rede Docker
docker network ls
docker network inspect data-platform-network

# Testar conectividade entre containers
docker exec airflow-webserver ping postgres
docker exec superset ping redis
```

**Solução:**
1. Todos os containers devem estar na mesma rede (`data-platform-network`)
2. Usar nome do container (não `localhost`) nas conexões:
   - ✅ `postgres:5432`
   - ❌ `localhost:5432`

3. Recriar a rede se necessário:
   ```bash
   docker compose down
   docker network rm data-platform-network
   docker compose up -d
   ```

---

### ❌ Não consigo acessar http://localhost:8080

**Diagnóstico:**
```bash
# Verificar se o container está rodando
docker compose ps airflow-webserver

# Verificar logs
docker compose logs airflow-webserver

# Testar dentro do container
docker exec airflow-webserver curl localhost:8080/health
```

**Soluções:**
1. Aguardar alguns minutos - serviços podem levar tempo para iniciar
2. Verificar firewall do Windows:
   ```powershell
   # Windows Defender Firewall
   # Adicionar regra de entrada para a porta 8080
   ```
3. Verificar mapeamento de portas:
   ```bash
   docker port airflow-webserver
   ```

---

## Problemas de Permissões

### ❌ "Permission denied" nos logs do Airflow (Linux/Mac)

**Sintoma:**
```
PermissionError: [Errno 13] Permission denied: '/opt/airflow/logs/...'
```

**Solução:**
```bash
# Ajustar permissões
sudo chown -R $(id -u):0 airflow/
chmod -R 755 airflow/
chmod -R 777 airflow/logs

# Recriar containers
docker compose down
docker compose up -d
```

---

### ❌ AIRFLOW_UID incorreto (Linux/Mac)

**Sintoma:**
Erros de permissão mesmo após ajustar

**Solução:**
```bash
# Adicionar UID correto no .env
echo "AIRFLOW_UID=$(id -u)" >> .env

# Recriar ambiente
docker compose down
docker compose up -d
```

---

## Problemas de Performance

### ❌ Containers muito lentos

**Diagnóstico:**
```bash
# Verificar uso de recursos
docker stats

# Verificar uso de memória
docker compose ps
```

**Soluções:**

1. **Aumentar recursos do Docker Desktop (Windows/Mac):**
   - Abrir Docker Desktop → Settings → Resources
   - Aumentar Memory para pelo menos 8GB
   - Aumentar CPU para 4 cores
   - Aplicar e reiniciar

2. **Reduzir paralelismo do Airflow:**
   ```env
   # .env
   AIRFLOW__CORE__PARALLELISM=16
   AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG=8
   ```

3. **Desabilitar Celery Worker se não for necessário:**
   - Mudar para LocalExecutor no `.env`
   - Comentar serviço `airflow-worker` no `docker-compose.yml`

---

### ❌ Disco cheio

**Diagnóstico:**
```bash
# Ver tamanho dos volumes Docker
docker system df -v

# Ver logs grandes
du -sh airflow/logs/*
```

**Solução:**
```bash
# Limpar logs antigos
docker exec airflow-scheduler airflow db clean --clean-before-timestamp $(date -d '30 days ago' +%Y-%m-%d)

# Limpar containers e imagens não usados
docker system prune -a --volumes

# CUIDADO: Remove TODOS os dados
docker compose down -v
```

---

## Problemas Específicos do Airflow

### ❌ DAGs não aparecem no Airflow UI

**Diagnóstico:**
```bash
# Verificar se DAG está na pasta correta
ls -la airflow/dags/

# Ver logs do scheduler
docker compose logs airflow-scheduler | grep -i error

# Verificar sintaxe da DAG
docker exec airflow-scheduler python /opt/airflow/dags/sua_dag.py
```

**Soluções:**
1. Verificar erros de sintaxe Python na DAG
2. Aguardar alguns segundos - Airflow faz scan periódico
3. Forçar rescan:
   ```bash
   docker exec airflow-scheduler airflow dags reserialize
   ```

---

### ❌ "Fernet key must be 32 url-safe base64-encoded bytes"

**Sintoma:**
Erro ao iniciar Airflow

**Solução:**
```bash
# Gerar Fernet key válida
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Ou usando Docker
docker run --rm python:3.11-slim sh -c "pip install cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"

# Copiar o resultado para AIRFLOW__CORE__FERNET_KEY no .env
# Recriar containers
docker compose down
docker compose up -d
```

---

### ❌ Tarefas ficam em estado "queued" indefinidamente

**Diagnóstico:**
```bash
# Verificar workers (CeleryExecutor)
docker compose logs airflow-worker

# Verificar scheduler
docker compose logs airflow-scheduler
```

**Soluções:**
1. Reiniciar scheduler:
   ```bash
   docker compose restart airflow-scheduler
   ```

2. Verificar se worker está rodando (CeleryExecutor):
   ```bash
   docker compose ps airflow-worker
   ```

3. Limpar tarefas antigas:
   ```bash
   docker exec airflow-scheduler airflow tasks clear dag_id
   ```

---

## Problemas Específicos do Superset

### ❌ "The CSRF token is missing"

**Sintoma:**
Erro ao fazer login no Superset

**Solução:**
1. Limpar cookies do navegador
2. Verificar `SUPERSET_SECRET_KEY` no `.env`:
   ```bash
   # Deve ter mínimo 42 caracteres
   SUPERSET_SECRET_KEY=valor_com_mais_de_42_caracteres_aleatorios
   ```
3. Recriar container:
   ```bash
   docker compose restart superset
   ```

---

### ❌ Não consigo conectar ao banco de dados no Superset

**Sintoma:**
Erro ao testar conexão com banco de dados

**Solução:**
1. Usar URI correto:
   ```
   # PostgreSQL (dentro do Docker)
   postgresql://usuario:senha@postgres:5432/nome_banco
   
   # MySQL (dentro do Docker)
   mysql://usuario:senha@mysql:3306/nome_banco
   ```

2. Instalar driver específico se necessário:
   ```bash
   docker exec superset pip install mysqlclient  # MySQL
   docker exec superset pip install pymssql      # SQL Server
   docker compose restart superset
   ```

---

### ❌ Gráficos não carregam / timeout

**Solução:**
1. Aumentar timeout:
   ```bash
   # Editar superset/config/superset_config.py
   SUPERSET_WEBSERVER_TIMEOUT = 600  # 10 minutos
   ```

2. Reiniciar worker:
   ```bash
   docker compose restart superset-worker
   ```

---

## Problemas Específicos do Hop

### ❌ Pipeline não encontrado pelo Hop

**Sintoma:**
```
ERROR: File not found: /opt/hop/projects/...
```

**Diagnóstico:**
```bash
# Verificar se arquivo existe no container
docker exec hop-server ls -la /opt/hop/projects/seu_projeto/pipelines/
```

**Solução:**
1. Verificar caminho completo do arquivo
2. Verificar volume montado:
   ```bash
   docker inspect hop-server | grep Mounts
   ```
3. Criar arquivo no diretório correto: `hop/projects/`

---

### ❌ Hop não consegue conectar ao banco de dados

**Solução:**
1. Usar hostname do container:
   ```
   ✅ postgres:5432
   ❌ localhost:5432
   ```

2. Verificar se banco está na mesma rede Docker
3. Testar conectividade:
   ```bash
   docker exec hop-server ping postgres
   ```

---

## Problemas com Banco de Dados

### ❌ PostgreSQL não inicia

**Diagnóstico:**
```bash
docker compose logs postgres
```

**Soluções:**

1. **Porta em uso:**
   ```bash
   # Alterar porta no .env
   POSTGRES_EXTERNAL_PORT=5433
   ```

2. **Volume corrompido:**
   ```bash
   docker compose down -v
   docker volume rm postgres-data
   docker compose up -d
   ```

3. **Falta de memória:**
   - Aumentar recursos do Docker Desktop

---

### ❌ Erro "password authentication failed"

**Solução:**
1. Verificar credenciais no `.env`
2. Recriar banco de dados:
   ```bash
   docker compose down -v
   docker compose up -d
   ```

---

## 🔧 Comandos Úteis de Diagnóstico

```bash
# Ver todos os containers
docker compose ps

# Ver logs de todos os serviços
docker compose logs

# Ver logs de serviço específico
docker compose logs -f airflow-scheduler

# Ver uso de recursos
docker stats

# Ver redes Docker
docker network ls

# Inspecionar rede
docker network inspect data-platform-network

# Ver volumes
docker volume ls

# Acessar shell de container
docker exec -it airflow-webserver bash

# Verificar healthcheck
docker inspect airflow-webserver | grep -A 10 Health

# Reiniciar serviço específico
docker compose restart airflow-scheduler

# Recriar serviço específico
docker compose up -d --force-recreate airflow-scheduler

# Limpar tudo e começar do zero
docker compose down -v
docker system prune -a
docker compose up -d
```

---

## 📞 Ainda com Problemas?

Se nenhuma das soluções acima funcionou:

1. **Verifique a documentação oficial:**
   - [Apache Airflow](https://airflow.apache.org/docs/)
   - [Apache Superset](https://superset.apache.org/docs/)
   - [Apache Hop](https://hop.apache.org/manual/)

2. **Colete informações para debug:**
   ```bash
   # Versões
   docker --version
   docker compose version
   
   # Status
   docker compose ps
   
   # Logs completos
   docker compose logs > debug-logs.txt
   
   # Configuração
   docker compose config
   ```

3. **Pesquise nos fóruns:**
   - GitHub Issues dos projetos
   - Stack Overflow
   - Reddit r/dataengineering

---

**Boa sorte com seu ambiente de dados!** 🚀
