# ⚡ Início Rápido - 5 Minutos

Guia super rápido para quem tem pressa e já conhece Docker.

---

## 🎯 Cenário 1: Ubuntu Server do Zero

**Tem Ubuntu Server recém-instalado?**

👉 **Consulte: [UBUNTU_SETUP.md](UBUNTU_SETUP.md)** - Guia completo passo a passo

---

## 🎯 Cenário 2: Docker já Instalado

### 1. Clone o repositório

```bash
git clone <url-repositorio>
cd superset_airflow_env
```

### 2. Configure ambiente

```bash
# Copiar template
cp .env.example .env

# Gerar chaves (escolha uma opção):

# Opção A: Com Python local
pip3 install cryptography
python3 generate_secrets.py

# Opção B: Com Docker (sem instalar nada)
docker run --rm python:3.11-slim sh -c "pip install -q cryptography && python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"

# Edite .env com as chaves geradas
nano .env  # ou vim .env
```

### 3. Ajuste permissões (Linux/Mac)

```bash
chmod +x quick-start.sh postgres/init-scripts/*.sh
sudo chown -R 50000:0 airflow/
chmod -R 777 airflow/logs
```

**Windows**: Pule esta etapa.

### 4. Inicialize

```bash
# Linux/Mac
./quick-start.sh

# Windows
.\quick-start.ps1

# Ou manualmente
docker compose up -d
```

### 5. Aguarde 2-5 minutos e acesse

- **Airflow**: http://localhost:8080 (admin/admin123)
- **Superset**: http://localhost:8088 (admin/admin123)
- **Hop**: http://localhost:8081 (cluster/cluster)

---

## ✅ Verificação Rápida

```bash
# Status
docker compose ps

# Logs
docker compose logs -f

# Tudo ok? Use o checklist:
```

👉 **[CHECKLIST.md](CHECKLIST.md)** - Verificação completa

---

## 🆘 Problemas?

👉 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Soluções para problemas comuns

---

## 📚 Documentação Completa

- **[README.md](README.md)** - Documentação detalhada
- **[UBUNTU_SETUP.md](UBUNTU_SETUP.md)** - Setup Ubuntu do zero
- **[CHECKLIST.md](CHECKLIST.md)** - Checklist completo
- **[hop/HOP_GUIDE.md](hop/HOP_GUIDE.md)** - Guia do Hop

---

## 🚀 Comandos Úteis

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f

# Parar
docker compose stop

# Iniciar
docker compose start

# Reiniciar
docker compose restart

# Destruir tudo (cuidado!)
docker compose down -v
```

---

**Pronto! Ambiente configurado em minutos!** ⚡
