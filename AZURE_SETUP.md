# 🌩️ Guia de Configuração - Azure

Este guia complementa o [UBUNTU_SETUP.md](UBUNTU_SETUP.md) com instruções específicas para implantação no **Microsoft Azure**.

---

## 🎯 Cenário

- VM Ubuntu no Azure
- IP Privado: 172.174.210.23
- Containers rodando mas não acessíveis externamente
- **Problema**: Network Security Group (NSG) bloqueando portas

---

## 🔥 Problema: Portas Bloqueadas no NSG

### Sintomas

```bash
# Containers rodando
docker compose ps  # ✅ Todos healthy/running

# Portas abertas no servidor
sudo ss -tlnp | grep 8080  # ✅ Docker escutando

# Acesso local funciona
curl http://localhost:8080  # ✅ Responde

# Acesso externo não funciona
curl http://172.174.210.23:8080  # ❌ Timeout
```

### Causa

O **Network Security Group (NSG)** do Azure está bloqueando tráfego de entrada nas portas 8080, 8088 e 8081.

---

## ✅ Solução: Configurar NSG no Azure Portal

### Passo 1: Acessar o Azure Portal

1. Acesse: https://portal.azure.com
2. Navegue até **Virtual Machines**
3. Selecione sua VM (ex: `apache` ou nome da sua VM)

### Passo 2: Configurar Network Security Group

#### Opção A: Via Portal Azure (Interface Gráfica)

1. Na página da VM, vá em **Networking** (Rede) no menu lateral
2. Clique em **Add inbound port rule** (Adicionar regra de porta de entrada)

3. **Para Airflow (porta 8080):**
   - **Source**: Any ou My IP (mais seguro)
   - **Source port ranges**: *
   - **Destination**: Any
   - **Service**: Custom
   - **Destination port ranges**: 8080
   - **Protocol**: TCP
   - **Action**: Allow
   - **Priority**: 300
   - **Name**: Allow-Airflow-8080
   - Clique em **Add**

4. **Para Superset (porta 8088):**
   - Repita o processo acima
   - **Destination port ranges**: 8088
   - **Priority**: 310
   - **Name**: Allow-Superset-8088

5. **Para Hop (porta 8081):**
   - Repita o processo
   - **Destination port ranges**: 8081
   - **Priority**: 320
   - **Name**: Allow-Hop-8081

#### Opção B: Via Azure CLI (Linha de Comando)

```bash
# Substitua pelos valores corretos
RESOURCE_GROUP="seu-resource-group"
NSG_NAME="nome-do-nsg"

# Permitir porta 8080 (Airflow)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Airflow-8080 \
  --protocol tcp \
  --priority 300 \
  --destination-port-range 8080 \
  --access Allow

# Permitir porta 8088 (Superset)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Superset-8088 \
  --protocol tcp \
  --priority 310 \
  --destination-port-range 8088 \
  --access Allow

# Permitir porta 8081 (Hop)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Hop-8081 \
  --protocol tcp \
  --priority 320 \
  --destination-port-range 8081 \
  --access Allow
```

### Passo 3: Verificar IP Público

O IP `172.174.210.23` é um **IP privado**. Para acessar de fora, você precisa do **IP público**.

**No Azure Portal:**
1. Vá na página da VM
2. Em **Overview** (Visão Geral), procure por **Public IP address**
3. Use esse IP para acessar os serviços

**Via Azure CLI:**
```bash
az vm show -d -g seu-resource-group -n nome-da-vm --query publicIps -o tsv
```

**Via SSH (dentro da VM):**
```bash
curl -s http://checkip.amazonaws.com
# ou
curl -s http://ifconfig.me
```

### Passo 4: Testar Acesso

Após configurar o NSG, teste o acesso:

```bash
# Substitua PUBLICO_IP pelo IP público da VM
curl -I http://PUBLICO_IP:8080/health  # Airflow
curl -I http://PUBLICO_IP:8088/health  # Superset
curl -I http://PUBLICO_IP:8081/        # Hop
```

---

## 🔐 Segurança: Restringir Acesso por IP

Para maior segurança, restrinja o acesso apenas ao seu IP:

### Via Portal Azure:

Na regra de NSG, em **Source**:
- Selecione: **My IP address**
- Ou selecione: **IP Addresses** e digite seu IP específico

### Via Azure CLI:

```bash
# Obter seu IP público
MEU_IP=$(curl -s http://checkip.amazonaws.com)

# Criar regra restrita
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Airflow-MyIP \
  --protocol tcp \
  --priority 300 \
  --destination-port-range 8080 \
  --source-address-prefix $MEU_IP/32 \
  --access Allow
```

---

## 🌐 Acessar os Serviços

Após configurar o NSG, acesse via **IP público**:

```
Airflow:  http://PUBLICO_IP:8080
Superset: http://PUBLICO_IP:8088
Hop:      http://PUBLICO_IP:8081
```

**Credenciais padrão:**
- Airflow: admin / admin123
- Superset: admin / admin123
- Hop: cluster / cluster

⚠️ **Altere as senhas padrão imediatamente!**

---

## 🔍 Diagnóstico de Problemas Azure

### Verificar se containers estão rodando

```bash
ssh -i ~/.ssh/sua-chave.pem azureuser@PUBLICO_IP
cd superset_airflow_env
docker compose ps
```

### Verificar portas abertas no servidor

```bash
sudo ss -tlnp | grep -E ':(8080|8088|8081)'
```

### Testar acesso local (dentro da VM)

```bash
curl -I http://localhost:8080/health  # Deve retornar 200 OK
curl -I http://localhost:8088/health
curl -I http://localhost:8081/
```

### Verificar logs de um serviço

```bash
docker compose logs -f airflow-webserver
docker compose logs -f superset
```

### Verificar NSG configurado

```bash
# Via Azure CLI
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --output table
```

---

## 📋 Checklist Azure

- [ ] VM criada no Azure
- [ ] Ubuntu Server instalado
- [ ] Docker e Docker Compose instalados
- [ ] Projeto clonado em ~/superset_airflow_env
- [ ] Arquivo .env configurado
- [ ] Containers iniciados (`docker compose up -d`)
- [ ] **NSG configurado com portas 8080, 8088, 8081 permitidas**
- [ ] **IP público identificado**
- [ ] Acesso testado via IP público
- [ ] Senhas padrão alteradas

---

## 🛡️ Melhores Práticas de Segurança Azure

### 1. Usar Azure Bastion (Recomendado)

Em vez de expor portas SSH e aplicação, use **Azure Bastion** para acesso seguro.

### 2. Configurar HTTPS com Let's Encrypt

```bash
# Instalar Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obter certificado (requer domínio)
sudo certbot --nginx -d seu-dominio.com
```

### 3. Usar Azure Application Gateway

Para produção, considere usar **Azure Application Gateway** com:
- WAF (Web Application Firewall)
- SSL/TLS termination
- Load balancing

### 4. Configurar Azure Monitor

Habilite monitoramento e alertas:
- CPU usage > 80%
- Memory usage > 80%
- Disk usage > 80%

### 5. Backups Automáticos

```bash
# Criar snapshot dos volumes Docker
docker run --rm -v postgres-data:/data -v ~/backups:/backup ubuntu \
  tar czf /backup/postgres-backup-$(date +%Y%m%d).tar.gz -C /data .
```

Configure **Azure Backup** para backups automáticos da VM.

---

## 🚀 Script Rápido de Configuração Azure

Crie um arquivo `azure-configure-nsg.sh`:

```bash
#!/bin/bash

# Variáveis - AJUSTE CONFORME SEU AMBIENTE
RESOURCE_GROUP="seu-resource-group"
NSG_NAME="nome-do-nsg"
MEU_IP=$(curl -s http://checkip.amazonaws.com)

echo "Configurando NSG para permitir portas 8080, 8088, 8081..."
echo "IP de origem: $MEU_IP"

# Airflow
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Airflow-8080 \
  --protocol tcp \
  --priority 300 \
  --destination-port-range 8080 \
  --source-address-prefix $MEU_IP/32 \
  --access Allow

# Superset
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Superset-8088 \
  --protocol tcp \
  --priority 310 \
  --destination-port-range 8088 \
  --source-address-prefix $MEU_IP/32 \
  --access Allow

# Hop
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name Allow-Hop-8081 \
  --protocol tcp \
  --priority 320 \
  --destination-port-range 8081 \
  --source-address-prefix $MEU_IP/32 \
  --access Allow

echo "NSG configurado! Teste o acesso."
```

Execute:
```bash
chmod +x azure-configure-nsg.sh
./azure-configure-nsg.sh
```

---

## 📚 Referências Azure

- [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Azure CLI - NSG](https://learn.microsoft.com/cli/azure/network/nsg)
- [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview)
- [Azure Application Gateway](https://learn.microsoft.com/azure/application-gateway/overview)

---

## 🆘 Ainda Não Funciona?

### 1. Verificar se a regra NSG foi aplicada

Aguarde 1-2 minutos após criar a regra NSG.

### 2. Verificar se usou o IP público correto

```bash
az vm show -d -g seu-resource-group -n nome-da-vm --query publicIps -o tsv
```

### 3. Verificar se containers estão healthy

```bash
ssh -i ~/.ssh/sua-chave.pem azureuser@IP-PUBLICO
docker compose ps
```

### 4. Consultar logs

```bash
docker compose logs airflow-webserver | tail -50
```

---

**Com o NSG configurado, você terá acesso completo à plataforma de dados!** 🚀
