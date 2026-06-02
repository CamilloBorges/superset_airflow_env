#!/bin/bash
# make-scripts-executable.sh - Torna todos os scripts executáveis
# ================================================================
# Execute este script após clonar o repositório para garantir
# que todos os scripts shell tenham permissão de execução.
#
# Uso:
#   chmod +x make-scripts-executable.sh
#   ./make-scripts-executable.sh
#
# ================================================================

echo "🔧 Tornando scripts executáveis..."
echo ""

# Scripts principais
chmod +x install.sh
echo "✓ install.sh"

chmod +x validate-installation.sh
echo "✓ validate-installation.sh"

chmod +x configure-cloudflare.sh
echo "✓ configure-cloudflare.sh"

chmod +x fix-sso-config.sh
echo "✓ fix-sso-config.sh"

chmod +x quick-start.sh
echo "✓ quick-start.sh"

chmod +x configure-azure-sso.sh
echo "✓ configure-azure-sso.sh"

# Scripts de geração de certificados
if [ -f "generate-ssl-cert.sh" ]; then
    chmod +x generate-ssl-cert.sh
    echo "✓ generate-ssl-cert.sh"
fi

if [ -f "generate-letsencrypt-cert.sh" ]; then
    chmod +x generate-letsencrypt-cert.sh
    echo "✓ generate-letsencrypt-cert.sh"
fi

# Scripts de inicialização do PostgreSQL
if [ -d "postgres/init-scripts" ]; then
    chmod +x postgres/init-scripts/*.sh 2>/dev/null
    echo "✓ postgres/init-scripts/*.sh"
fi

# Outros scripts
chmod +x make-scripts-executable.sh 2>/dev/null

echo ""
echo "✅ Todos os scripts estão executáveis!"
echo ""
echo "Próximos passos:"
echo "  1. ./install.sh --help              # Ver opções de instalação"
echo "  2. cp install.config.example install.config"
echo "  3. nano install.config              # Editar configuração"
echo "  4. ./install.sh --config install.config"
echo ""
