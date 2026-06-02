# 🔐 Boas Práticas de Segurança

## 🚨 Nunca Commite Secrets no Git!

### ❌ O Que NÃO Fazer

```bash
# ERRADO - Secrets hardcoded
AZURE_CLIENT_SECRET=abc123***EXEMPLO-NAO-USE***xyz789
DATABASE_PASSWORD=minhasenha123
API_KEY=exemplo_api_key_nao_real
```

### ✅ O Que Fazer

```bash
# CORRETO - Usar placeholders
AZURE_CLIENT_SECRET=seu-client-secret-aqui
DATABASE_PASSWORD=sua-senha-segura-aqui
API_KEY=sua-api-key-aqui
```

---

## 🛡️ Proteção Implementada

### 1. GitHub Push Protection

O GitHub **bloqueia automaticamente** push com secrets detectados:
- Azure AD Client Secrets
- AWS Access Keys
- API Tokens
- Senhas em texto plano

**Erro típico:**
```
remote: error: GH013: Repository rule violations found
remote: - Push cannot contain secrets
```

### 2. .gitignore Configurado

Arquivos que **nunca** devem ser commitados:

```gitignore
# Variáveis de ambiente
.env
*.env
!.env.example

# Arquivos de configuração com secrets
airflow/config/webserver_config.py
superset/config/superset_config.py

# Certificados SSL
*.pem
*.key
*.crt

# Arquivos temporários
*.txt
Untitled-*
```

### 3. Templates com Placeholders

Use sempre `.example` files:

```bash
# Template versionado
.env.example           ✅ (commitar)

# Arquivo real com secrets
.env                   ❌ (NÃO commitar)
```

---

## 🚑 Se Você Expôs um Secret

### Passo 1: Remover do Git

```bash
# Voltar commits
git reset --soft HEAD~1

# Remover secret do arquivo
nano arquivo-com-secret.md

# Fazer novo commit
git add .
git commit -m "fix: Remove exposed secrets"
git push
```

### Passo 2: Revogar o Secret Exposto

**Azure AD Client Secret:**
1. Azure Portal → App Registrations
2. Seu App → Certificates & secrets
3. Delete o secret comprometido
4. Generate new client secret
5. Atualizar `.env` no servidor

**Outros Secrets:**
- AWS: Revogar access keys
- API Keys: Regenerar no serviço
- Senhas: Trocar imediatamente

### Passo 3: Atualizar Aplicação

```bash
# SSH no servidor
ssh -i ~/.ssh/key.pem user@server

# Atualizar .env
nano .env

# Reiniciar containers
docker compose down
docker compose up -d
```

---

## 📋 Checklist de Segurança

Antes de fazer commit:

- [ ] Verificar se `.env` está no `.gitignore`
- [ ] Nenhum secret hardcoded em arquivos
- [ ] Arquivos de configuração usam `os.getenv()`
- [ ] Arquivos temporários removidos
- [ ] Review do diff: `git diff --cached`

Antes de fazer push:

- [ ] `git log -p` para revisar commits
- [ ] Nenhum arquivo `.txt` ou `Untitled-*` foi adicionado
- [ ] Documentação usa placeholders

---

## 🔍 Como Verificar Secrets em Commits

```bash
# Ver arquivos no último commit
git show HEAD --name-only

# Ver diff completo do último commit
git show HEAD

# Procurar por patterns de secrets
git log -p | grep -E "(SECRET|PASSWORD|KEY|TOKEN)" -i

# Verificar arquivos staged antes do commit
git diff --cached
```

---

## 🛠️ Ferramentas Úteis

### 1. git-secrets (AWS)

```bash
# Instalar
brew install git-secrets  # Mac
# ou
git clone https://github.com/awslabs/git-secrets.git

# Configurar
git secrets --install
git secrets --register-aws
```

### 2. gitleaks

```bash
# Instalar
brew install gitleaks  # Mac

# Scan do repositório
gitleaks detect --source . --verbose
```

### 3. pre-commit hooks

Criar `.git/hooks/pre-commit`:

```bash
#!/bin/bash
if git diff --cached | grep -iE "(secret|password|key.*=.*[a-z0-9]{20,})"; then
    echo "⚠️  AVISO: Possível secret detectado!"
    echo "Review your changes before committing."
    exit 1
fi
```

---

## 🎓 Boas Práticas

### 1. Use Variáveis de Ambiente

**Python:**
```python
import os

# ✅ CORRETO
client_secret = os.getenv('AZURE_CLIENT_SECRET')

# ❌ ERRADO
client_secret = 'abc123***EXEMPLO-NAO-USE***xyz789'
```

**Bash:**
```bash
# ✅ CORRETO
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# ❌ ERRADO
POSTGRES_PASSWORD=minhasenha123
```

### 2. Sempre Use .env.example

```bash
# .env.example (commitar)
DATABASE_PASSWORD=sua-senha-segura-aqui
API_KEY=sua-api-key-aqui

# .env (NÃO commitar)
DATABASE_PASSWORD=s3nh4_r34l_s3gur4
API_KEY=abc123xyz789real
```

### 3. Rotação de Secrets

- [ ] Trocar secrets a cada 90 dias
- [ ] Usar secrets diferentes por ambiente
- [ ] Documentar processo de rotação

### 4. Princípio do Menor Privilégio

- Criar service accounts específicos
- Permissões mínimas necessárias
- Não usar contas pessoais em produção

---

## 📚 Recursos Adicionais

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [OWASP Secrets Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [12 Factor App - Config](https://12factor.net/config)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)

---

**🔒 Lembre-se: Um secret exposto = comprometimento total do sistema!**
