# =============================================================================
# Quick Start Script - Data Platform
# =============================================================================
# Script de inicialização rápida para Windows (PowerShell)
#
# Uso:
#   .\quick-start.ps1
# =============================================================================

Write-Host "========================================" -ForegroundColor Green
Write-Host "  Data Platform - Quick Start" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Verificar se Docker está rodando
Write-Host "Verificando Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker encontrado: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker não está instalado ou não está rodando!" -ForegroundColor Red
    Write-Host "  Por favor, instale o Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Verificar se Docker Compose está disponível
Write-Host "Verificando Docker Compose..." -ForegroundColor Yellow
try {
    $composeVersion = docker compose version
    Write-Host "✓ Docker Compose encontrado: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker Compose não está disponível!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Verificar se arquivo .env existe
if (-not (Test-Path ".env")) {
    Write-Host "Arquivo .env não encontrado. Criando a partir do template..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "✓ Arquivo .env criado!" -ForegroundColor Green
    Write-Host ""
    Write-Host "ATENÇÃO: Você precisa gerar as chaves de segurança!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Execute um dos comandos abaixo para gerar as chaves:" -ForegroundColor Yellow
    Write-Host "  1. Se tiver Python instalado:" -ForegroundColor Cyan
    Write-Host "     python generate_secrets.py" -ForegroundColor White
    Write-Host ""
    Write-Host "  2. Usando Docker:" -ForegroundColor Cyan
    Write-Host '     docker run --rm python:3.11-slim sh -c "pip install cryptography && python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""' -ForegroundColor White
    Write-Host ""
    Write-Host "Depois de gerar as chaves, edite o arquivo .env com os valores gerados." -ForegroundColor Yellow
    Write-Host ""
    
    $continue = Read-Host "Deseja continuar mesmo assim? (S/N)"
    if ($continue -ne "S" -and $continue -ne "s") {
        Write-Host "Abortando..." -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "✓ Arquivo .env encontrado!" -ForegroundColor Green
}

Write-Host ""

# Verificar se as chaves foram alteradas do padrão
Write-Host "Verificando configurações de segurança..." -ForegroundColor Yellow
$envContent = Get-Content ".env" -Raw
if ($envContent -match "changeme") {
    Write-Host "⚠ AVISO: Algumas senhas ainda estão com valores padrão!" -ForegroundColor Red
    Write-Host "  Recomenda-se alterar antes de prosseguir em produção." -ForegroundColor Yellow
    Write-Host ""
}

# Criar diretórios necessários
Write-Host "Criando estrutura de diretórios..." -ForegroundColor Yellow
$directories = @(
    "airflow\logs",
    "airflow\dags", 
    "airflow\plugins",
    "airflow\config",
    "superset\config",
    "superset\data",
    "hop\config",
    "hop\projects",
    "hop\metadata",
    "postgres\init-scripts",
    "shared\data"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}
Write-Host "✓ Estrutura de diretórios criada!" -ForegroundColor Green
Write-Host ""

# Baixar imagens Docker
Write-Host "Baixando imagens Docker (isso pode levar alguns minutos)..." -ForegroundColor Yellow
docker compose pull

Write-Host ""
Write-Host "✓ Imagens baixadas!" -ForegroundColor Green
Write-Host ""

# Iniciar serviços
Write-Host "Iniciando serviços..." -ForegroundColor Yellow
Write-Host "Isso pode levar de 2 a 5 minutos na primeira vez." -ForegroundColor Cyan
Write-Host ""
docker compose up -d

Write-Host ""
Write-Host "✓ Serviços iniciados!" -ForegroundColor Green
Write-Host ""

# Aguardar serviços ficarem prontos
Write-Host "Aguardando serviços iniciarem (pode levar até 2 minutos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Verificar status
Write-Host ""
Write-Host "Status dos serviços:" -ForegroundColor Yellow
docker compose ps

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Inicialização Concluída!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse as interfaces web:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Apache Airflow:  http://localhost:8080" -ForegroundColor White
Write-Host "    Usuário: admin" -ForegroundColor Gray
Write-Host "    Senha:   admin123" -ForegroundColor Gray
Write-Host ""
Write-Host "  Apache Superset: http://localhost:8088" -ForegroundColor White
Write-Host "    Usuário: admin" -ForegroundColor Gray
Write-Host "    Senha:   admin123" -ForegroundColor Gray
Write-Host ""
Write-Host "  Apache Hop:      http://localhost:8081" -ForegroundColor White
Write-Host "    Usuário: cluster" -ForegroundColor Gray
Write-Host "    Senha:   cluster" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠ IMPORTANTE: Altere as senhas padrão após o primeiro login!" -ForegroundColor Red
Write-Host ""
Write-Host "Comandos úteis:" -ForegroundColor Cyan
Write-Host "  Ver logs:         docker compose logs -f" -ForegroundColor White
Write-Host "  Parar serviços:   docker compose stop" -ForegroundColor White
Write-Host "  Iniciar serviços: docker compose start" -ForegroundColor White
Write-Host "  Status:           docker compose ps" -ForegroundColor White
Write-Host ""
Write-Host "Documentação completa: README.md" -ForegroundColor Yellow
Write-Host ""
