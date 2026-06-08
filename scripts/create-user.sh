#!/bin/bash
# =============================================================================
# Script Simplificado para Criar Usuários LDAP
# =============================================================================
# Uso: ./scripts/create-user.sh
# ou:  make user
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}           🧑 Criar Novo Usuário LDAP - Simplificado${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Carregar variáveis do .env
if [ ! -f .env ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    echo "Execute este script a partir do diretório data-platform/"
    exit 1
fi

source .env

# =============================================================================
# Coletar Informações do Usuário
# =============================================================================

echo -e "${YELLOW}📝 Preencha os dados do novo usuário:${NC}"
echo ""

# Nome completo
read -p "Nome completo (ex: João Silva): " FULL_NAME
if [ -z "$FULL_NAME" ]; then
    echo -e "${RED}❌ Nome é obrigatório!${NC}"
    exit 1
fi

# Primeiro nome e sobrenome
FIRST_NAME=$(echo "$FULL_NAME" | awk '{print $1}')
LAST_NAME=$(echo "$FULL_NAME" | awk '{$1=""; print $0}' | xargs)

if [ -z "$LAST_NAME" ]; then
    LAST_NAME=$FIRST_NAME
fi

# Username (uid)
read -p "Username (ex: joao.silva): " USERNAME
if [ -z "$USERNAME" ]; then
    echo -e "${RED}❌ Username é obrigatório!${NC}"
    exit 1
fi

# Email
read -p "Email (ex: joao.silva@bomgado.local): " EMAIL
if [ -z "$EMAIL" ]; then
    EMAIL="${USERNAME}@bomgado.local"
fi

# Senha
read -s -p "Senha: " PASSWORD
echo ""
read -s -p "Confirme a senha: " PASSWORD_CONFIRM
echo ""

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}❌ As senhas não coincidem!${NC}"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo -e "${RED}❌ Senha é obrigatória!${NC}"
    exit 1
fi

# Grupo
echo ""
echo -e "${YELLOW}👥 Selecione o grupo (perfil de acesso):${NC}"
echo ""
echo "  1) 🔑 Administradores (Admin em Superset/Airflow - acesso total)"
echo "  2) 📊 Analistas (Alpha/Op - criar/editar dashboards e workflows)"
echo "  3) 👁️  Visualizadores (Gamma/Viewer - somente leitura)"
echo ""
read -p "Escolha [1-3]: " GROUP_CHOICE

case $GROUP_CHOICE in
    1)
        GROUP_CN="admins"
        GROUP_DESC="Administradores"
        GID_NUMBER="10001"
        ;;
    2)
        GROUP_CN="analysts"
        GROUP_DESC="Analistas"
        GID_NUMBER="10002"
        ;;
    3)
        GROUP_CN="viewers"
        GROUP_DESC="Visualizadores"
        GID_NUMBER="10003"
        ;;
    *)
        echo -e "${RED}❌ Opção inválida!${NC}"
        exit 1
        ;;
esac

# =============================================================================
# Gerar uidNumber único
# =============================================================================

# Buscar último uidNumber usado
LAST_UID=$(docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "ou=users,dc=bomgado,dc=local" \
    "(uidNumber=*)" uidNumber 2>/dev/null | \
    grep "uidNumber:" | awk '{print $2}' | sort -n | tail -1)

if [ -z "$LAST_UID" ]; then
    NEW_UID=10001
else
    NEW_UID=$((LAST_UID + 1))
fi

# =============================================================================
# Confirmar Dados
# =============================================================================

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${YELLOW}📋 Confirme os dados:${NC}"
echo ""
echo "  Nome completo: $FULL_NAME"
echo "  Username: $USERNAME"
echo "  Email: $EMAIL"
echo "  Grupo: $GROUP_DESC ($GROUP_CN)"
echo "  UID Number: $NEW_UID"
echo ""
read -p "Criar usuário? [S/n]: " CONFIRM

if [[ ! $CONFIRM =~ ^[Ss]?$ ]]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

# =============================================================================
# Criar Usuário no LDAP
# =============================================================================

echo ""
echo -e "${YELLOW}⏳ Criando usuário no LDAP...${NC}"

# Criar arquivo LDIF
cat > /tmp/new-user-$USERNAME.ldif <<EOF
dn: cn=$FULL_NAME,ou=users,dc=bomgado,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: $FULL_NAME
sn: $LAST_NAME
givenName: $FIRST_NAME
uid: $USERNAME
uidNumber: $NEW_UID
gidNumber: $GID_NUMBER
homeDirectory: /home/$USERNAME
loginShell: /bin/bash
mail: $EMAIL
userPassword: $PASSWORD
description: Created via simplified script on $(date +%Y-%m-%d)
EOF

# Adicionar usuário
docker exec openldap ldapadd -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -f /tmp/new-user-$USERNAME.ldif 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Usuário criado com sucesso!${NC}"
else
    echo -e "${RED}❌ Erro ao criar usuário!${NC}"
    rm -f /tmp/new-user-$USERNAME.ldif
    exit 1
fi

# =============================================================================
# Adicionar ao Grupo
# =============================================================================

echo -e "${YELLOW}⏳ Adicionando ao grupo $GROUP_DESC...${NC}"

# Adicionar ao groupOfNames (para autenticação Superset/Airflow)
cat > /tmp/add-to-group-$USERNAME.ldif <<EOF
dn: cn=$GROUP_CN,ou=groups,dc=bomgado,dc=local
changetype: modify
add: member
member: cn=$FULL_NAME,ou=users,dc=bomgado,dc=local
EOF

docker exec openldap ldapmodify -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -f /tmp/add-to-group-$USERNAME.ldif 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Usuário adicionado ao grupo LDAP com sucesso!${NC}"
else
    echo -e "${YELLOW}⚠️  Aviso: Erro ao adicionar ao grupo LDAP (usuário foi criado)${NC}"
fi

# Adicionar ao posixGroup (para LAM e gestão UNIX)
echo -e "${YELLOW}⏳ Adicionando ao grupo POSIX...${NC}"

cat > /tmp/add-to-posix-$USERNAME.ldif <<EOF
dn: cn=posix-$GROUP_CN,ou=groups,dc=bomgado,dc=local
changetype: modify
add: memberUid
memberUid: $USERNAME
EOF

docker exec openldap ldapmodify -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -f /tmp/add-to-posix-$USERNAME.ldif 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Usuário adicionado ao grupo POSIX com sucesso!${NC}"
else
    echo -e "${YELLOW}⚠️  Aviso: Erro ao adicionar ao grupo POSIX${NC}"
fi

# Limpar arquivos temporários
rm -f /tmp/new-user-$USERNAME.ldif /tmp/add-to-group-$USERNAME.ldif /tmp/add-to-posix-$USERNAME.ldif

# =============================================================================
# Resumo Final
# =============================================================================

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}                    ✅ USUÁRIO CRIADO!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo -e "${YELLOW}📧 Envie estas informações ao usuário:${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🔐 Credenciais de Acesso${NC}"
echo ""
echo "  Usuário: $USERNAME"
echo "  Senha: $PASSWORD"
echo "  Email: $EMAIL"
echo "  Perfil: $GROUP_DESC"
echo ""
echo -e "${BLUE}🌐 URLs de Acesso${NC}"
echo ""
echo "  Superset (BI):  https://bi.bomgado.com.br"
echo "  Airflow (ETL):  https://airflow.bomgado.com.br"
echo "  Apache Hop:     https://hop.bomgado.com.br"
echo ""
echo -e "${BLUE}📋 Permissões${NC}"
echo ""
case $GROUP_CHOICE in
    1)
        echo "  ✅ Administração completa (criar/editar/excluir)"
        echo "  ✅ Gerenciar usuários e permissões"
        echo "  ✅ Configurações do sistema"
        ;;
    2)
        echo "  ✅ Criar e editar dashboards/workflows"
        echo "  ✅ Executar consultas e pipelines"
        echo "  ❌ Gerenciar usuários (somente admin)"
        ;;
    3)
        echo "  ✅ Visualizar dashboards e relatórios"
        echo "  ❌ Editar ou criar conteúdo"
        echo "  ❌ Gerenciar usuários"
        ;;
esac
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}💡 Dica:${NC} Peça ao usuário para trocar a senha no primeiro login!"
echo ""

# =============================================================================
# Verificação
# =============================================================================

echo -e "${YELLOW}🔍 Verificando criação...${NC}"

docker exec openldap ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=bomgado,dc=local" \
    -w "${LDAP_ADMIN_PASSWORD}" \
    -b "ou=users,dc=bomgado,dc=local" \
    "(uid=$USERNAME)" cn mail 2>&1 | grep -E "^(dn:|cn:|mail:)" | head -3

echo ""
echo -e "${GREEN}✓ Processo concluído!${NC}"
echo ""
