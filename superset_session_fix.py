with open('superset/config/superset_config.py', 'r') as f:
    lines = f.readlines()

with open('superset/config/superset_config.py', 'w') as f:
    for i, line in enumerate(lines):
        # Atualizar CSRF exempt list para incluir rotas de logging
        if line.startswith('WTF_CSRF_EXEMPT_LIST'):
            f.write("WTF_CSRF_EXEMPT_LIST = ['oauth-authorized', 'superset/log']\n")
        # Atualizar SameSite para None (necessário para OAuth cross-site)
        elif line.strip() == "SESSION_COOKIE_SAMESITE = 'Lax'":
            f.write("SESSION_COOKIE_SAMESITE = None  # Permite OAuth cross-site\n")
        # Atualizar SECURE para True quando SameSite=None
        elif 'SESSION_COOKIE_SECURE = False' in line:
            f.write("SESSION_COOKIE_SECURE = True  # Obrigatório quando SameSite=None\n")
        # Adicionar configuração de domínio após SESSION_COOKIE_SECURE
        elif i > 0 and 'SESSION_COOKIE_SECURE' in lines[i-1]:
            f.write(line)
            if not any('SESSION_COOKIE_DOMAIN' in l for l in lines[i:i+3]):
                f.write("SESSION_COOKIE_DOMAIN = '.bomgado.com.br'  # Cookie funciona em subdomínios\n")
        else:
            f.write(line)

print('Configuração de sessão OAuth atualizada!')
