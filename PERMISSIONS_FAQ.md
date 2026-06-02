# ❓ FAQ - Permissões e Sudo

## 🔐 Devo executar install.sh com sudo?

**❌ NÃO!** Execute como usuário normal:

```bash
# ❌ ERRADO
sudo ./install.sh --auto

# ✅ CORRETO
./install.sh --auto
```

---

## 🤔 Por que não usar sudo?

1. **Segurança** - Executar scripts inteiros como root é má prática
2. **Ownership** - Arquivos criados teriam dono errado (root ao invés do seu usuário)
3. **Validação** - O script verifica e bloqueia execução como root
4. **Desnecessário** - O script pede sudo apenas quando realmente precisa

---

## 🐳 E as permissões do Docker?

### O que acontece:

1. **Durante instalação:**
   ```
   → Adicionando usuário ao grupo docker...
   ✓ Usuário azureuser adicionado ao grupo docker
   ℹ Usando 'sudo docker' durante instalação
   ```

2. **Script detecta automaticamente:**
   - Se você já tem permissões Docker → usa `docker` normalmente
   - Se você não tem permissões ainda → usa `sudo docker` automaticamente

3. **Comandos Docker durante instalação:**
   ```bash
   # Internamente o script usa:
   sudo docker run --rm python:3.11-slim ...  # Gerar Fernet Key
   sudo docker compose pull                    # Baixar imagens
   sudo docker compose up -d                   # Iniciar containers
   ```

4. **Após instalação (logout/login):**
   ```bash
   # Não precisa mais de sudo
   docker compose ps
   docker compose logs -f
   docker compose restart
   ```

---

## 🔧 Erro: "permission denied while trying to connect to the Docker daemon socket"

### Causa
Você acabou de ser adicionado ao grupo `docker`, mas a permissão só é aplicada em uma nova sessão.

### Soluções

#### Opção 1: Deixar o script continuar (Recomendado)
```bash
# O script já trata isso automaticamente!
# Usa 'sudo docker' durante instalação
# Você só precisa fazer logout/login DEPOIS
./install.sh --auto
```

#### Opção 2: Aplicar permissões antes de instalar
```bash
# Entrar em nova sessão com grupo docker
newgrp docker

# Executar instalação
./install.sh --auto
```

#### Opção 3: Logout/Login e executar depois
```bash
# Fazer logout do SSH
exit

# Fazer login novamente
ssh user@server

# Executar instalação (agora tem permissões)
cd data-platform
./install.sh --auto
```

---

## 📊 Comparação de Abordagens

| Abordagem | Segurança | Ownership Correto | Funciona? | Recomendado |
|-----------|-----------|-------------------|-----------|-------------|
| `sudo ./install.sh` | ❌ Ruim | ❌ Não | ⚠️ Script bloqueia | ❌ Não |
| `./install.sh` (sem permissões Docker) | ✅ Boa | ✅ Sim | ✅ Usa sudo automaticamente | ✅ **Sim** |
| `newgrp docker && ./install.sh` | ✅ Boa | ✅ Sim | ✅ Não precisa sudo | ✅ Sim (alternativa) |

---

## 🎯 Fluxo Recomendado

### 1️⃣ Instalação (usuário sem permissões Docker)
```bash
# Clone repositório
git clone <url> data-platform
cd data-platform

# Execute instalação (NÃO use sudo)
chmod +x install.sh
./install.sh --auto

# Script adiciona você ao grupo docker
# Script usa 'sudo docker' automaticamente durante instalação
# ✓ Instalação completa!
```

### 2️⃣ Aplicar permissões Docker permanentemente
```bash
# Fazer logout
exit

# Fazer login novamente
ssh user@server

# Agora pode usar docker sem sudo
docker compose ps
docker compose logs -f
```

### 3️⃣ Uso diário
```bash
# Comandos normais (sem sudo)
docker compose ps
docker compose logs superset
docker compose restart airflow-webserver
docker compose down
docker compose up -d
```

---

## 🛡️ Validação de Permissões

### Verificar se você tem permissões Docker:
```bash
docker ps
```

**Se funcionar:** ✅ Tem permissões  
**Se der erro:** ❌ Precisa logout/login ou newgrp docker

### Verificar grupos do usuário:
```bash
groups
```

**Deve aparecer:** `docker` na lista

### Forçar aplicação de permissões sem logout:
```bash
newgrp docker
```

---

## 📝 Resumo

✅ **Execute install.sh como usuário normal** (não root, não sudo)  
✅ **Script usa sudo automaticamente** apenas para comandos que precisam  
✅ **Após instalação, faça logout/login** para aplicar permissões Docker  
✅ **Depois disso, use docker normalmente** sem sudo  

❌ **Nunca execute `sudo ./install.sh`**  
❌ **Não execute como root**  

---

## 🆘 Ainda com problemas?

Consulte:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Solução de problemas gerais
- [AUTOMATION_SCRIPTS_GUIDE.md](AUTOMATION_SCRIPTS_GUIDE.md) - Guia dos scripts
- [AUTOMATED_INSTALL.md](AUTOMATED_INSTALL.md) - Guia de instalação automatizada
