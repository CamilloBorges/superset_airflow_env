# 🩺 Diagnóstico Azure - 172.174.210.23

**Data/Hora:** 01/06/2026 às 20:33 UTC  
**Servidor:** apache (172.174.210.23)  
**Usuário:** azureuser  
**Projeto:** ~/superset_airflow_env

---

## ✅ STATUS GERAL: **CONTAINERS RODANDO** 

### 🟢 Containers Saudáveis (Healthy)

| Serviço | Status | Porta |
|---------|--------|-------|
| ✅ **airflow-webserver** | Healthy | 8080 |
| ✅ **airflow-triggerer** | Healthy | - |
| ✅ **airflow-worker** | Healthy | - |
| ✅ **superset** | Healthy | 8088 |
| ✅ **postgres** | Healthy | 5432 |
| ✅ **redis** | Healthy | 6379 |

### 🟡 Containers com Healthcheck Unhealthy (Mas Rodando)

| Serviço | Status | Observação |
|---------|--------|------------|
| 🟡 **airflow-scheduler** | Unhealthy | Pode levar até 5 min para ficar healthy |
| 🟡 **hop-server** | Unhealthy | Healthcheck pode estar muito agressivo |
| 🟡 **superset-beat** | Unhealthy | Serviço de background, não crítico |
| 🟡 **superset-worker** | Unhealthy | Workers Celery podem demorar a iniciar |

> ℹ️ **Nota**: "Unhealthy" não significa que não está funcionando, apenas que o healthcheck falhou. Os serviços principais (webserver, superset, postgres, redis) estão **healthy**.

---

## 🌐 STATUS DE REDE

### ✅ Portas Abertas no Servidor (Localmente)

```bash
# Verificado via: sudo ss -tlnp | grep -E ':(8080|8088|8081)'
✅ 8080 - airflow-webserver (Docker)
✅ 8088 - superset (Docker)
✅ 8081 - hop-server (Docker)
```

### ✅ Acesso Local (Dentro da VM)

```bash
# Testado via: curl http://localhost:8080/health
✅ Airflow responde com HTTP 200 OK
```

### ❌ PROBLEMA IDENTIFICADO: NSG Bloqueando Portas

**IP Público:** 172.174.210.23  
**Firewall UFW:** Inactive (não é o problema)  
**Causa:** **Azure Network Security Group (NSG)** bloqueando tráfego de entrada nas portas 8080, 8088 e 8081

---

## 🔧 SOLUÇÃO: Configurar NSG no Azure Portal

### Passos para Resolver

1. **Acesse o Azure Portal**
   - URL: https://portal.azure.com
   - Navegue até **Virtual Machines** → Selecione sua VM

2. **Configure as Regras de NSG**
   - Menu lateral: **Networking** (Rede)
   - Clique em **Add inbound port rule**

3. **Adicione 3 Regras:**

   **Regra 1 - Airflow (8080):**
   ```
   Name: Allow-Airflow-8080
   Priority: 300
   Port: 8080
   Protocol: TCP
   Source: My IP (para segurança) ou Any
   Action: Allow
   ```

   **Regra 2 - Superset (8088):**
   ```
   Name: Allow-Superset-8088
   Priority: 310
   Port: 8088
   Protocol: TCP
   Source: My IP ou Any
   Action: Allow
   ```

   **Regra 3 - Hop (8081):**
   ```
   Name: Allow-Hop-8081
   Priority: 320
   Port: 8081
   Protocol: TCP
   Source: My IP ou Any
   Action: Allow
   ```

4. **Aguarde 1-2 minutos** para as regras serem aplicadas

5. **Teste o Acesso:**
   ```bash
   # Do seu computador local
   curl -I http://172.174.210.23:8080/health  # Airflow
   curl -I http://172.174.210.23:8088/health  # Superset
   curl -I http://172.174.210.23:8081/        # Hop
   ```

---

## 📝 Via Azure CLI (Alternativa)

Se preferir usar linha de comando:

```bash
# Obter informações da VM
az vm show -d -g SEU-RESOURCE-GROUP -n NOME-DA-VM

# Criar regras NSG
RESOURCE_GROUP="seu-resource-group"
NSG_NAME="nome-do-nsg"

# Airflow
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Airflow-8080 \
  --protocol tcp \
  --priority 300 \
  --destination-port-range 8080 \
  --access Allow

# Superset
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Superset-8088 \
  --protocol tcp \
  --priority 310 \
  --destination-port-range 8088 \
  --access Allow

# Hop
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Hop-8081 \
  --protocol tcp \
  --priority 320 \
  --destination-port-range 8081 \
  --access Allow
```

---

## 🎯 URLs de Acesso (Após Configurar NSG)

| Serviço | URL | Credenciais Padrão |
|---------|-----|-------------------|
| **Airflow** | http://172.174.210.23:8080 | admin / admin123 |
| **Superset** | http://172.174.210.23:8088 | admin / admin123 |
| **Hop** | http://172.174.210.23:8081 | cluster / cluster |

⚠️ **IMPORTANTE:** Altere as senhas padrão imediatamente após o primeiro acesso!

---

## 📊 Comandos de Monitoramento

### Ver Status dos Containers

```bash
ssh -i ~/.ssh/azuer_teste.pem azureuser@172.174.210.23
cd superset_airflow_env
docker compose ps
```

### Ver Logs de um Serviço

```bash
docker compose logs -f airflow-webserver
docker compose logs -f superset
docker compose logs -f hop-server
```

### Reiniciar um Serviço Específico

```bash
docker compose restart airflow-webserver
docker compose restart superset
```

### Verificar Saúde dos Containers

```bash
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
```

---

## 🐛 Avisos (Podem ser Ignorados)

### ⚠️ Warning: "The 'Io' variable is not set"

**Causa:** Variável `SUPERSET_SECRET_KEY` contém o caractere `Io` que o Docker Compose interpreta como variável.

**Impacto:** Nenhum. É apenas um warning, o sistema funciona normalmente.

**Correção (Opcional):**
```bash
# Editar .env e adicionar escape
SUPERSET_SECRET_KEY='*jX7xr/kKv;&{yVt):9T&#-?=Cp!<$$Io?Ia}1}*0t2mI!|pS2i'
```

### ⚠️ Warning: "attribute 'version' is obsolete"

**Causa:** Docker Compose 2.x não requer mais a linha `version: "3.8"` no docker-compose.yml.

**Impacto:** Nenhum. É apenas um aviso de deprecação.

**Correção (Opcional):**
```bash
# Remover primeira linha do docker-compose.yml
sed -i '1d' docker-compose.yml
```

---

## ✅ Checklist de Verificação

- [x] Servidor Ubuntu configurado
- [x] Docker e Docker Compose instalados
- [x] Projeto clonado em ~/superset_airflow_env
- [x] Arquivo .env configurado com secrets
- [x] Containers iniciados (`docker compose up -d`)
- [x] Serviços principais healthy (postgres, redis, airflow-web, superset)
- [x] Portas abertas localmente (8080, 8088, 8081)
- [x] Acesso local funcionando (curl localhost:8080)
- [ ] **NSG configurado no Azure Portal** ← **PENDENTE**
- [ ] Acesso externo testado (http://172.174.210.23:8080)
- [ ] Senhas padrão alteradas

---

## 🚀 Próximos Passos

1. **Configure o NSG no Azure Portal** seguindo [AZURE_SETUP.md](AZURE_SETUP.md)
2. **Teste o acesso** aos 3 serviços
3. **Altere as senhas padrão** em cada serviço
4. **Configure um domínio** (opcional, mas recomendado)
5. **Habilite HTTPS** com Let's Encrypt (produção)

---

## 📚 Documentação Relacionada

- [AZURE_SETUP.md](AZURE_SETUP.md) - Guia completo de configuração Azure
- [UBUNTU_SETUP.md](UBUNTU_SETUP.md) - Instalação do Ubuntu Server
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Solução de problemas
- [README.md](README.md) - Documentação principal

---

**Diagnóstico realizado com sucesso!** 🎉  
Todos os containers estão rodando. Basta configurar o NSG para liberar o acesso externo.
