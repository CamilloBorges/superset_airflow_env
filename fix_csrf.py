#!/usr/bin/env python3
with open('superset/config/superset_config.py', 'r') as f:
    lines = f.readlines()

with open('superset/config/superset_config.py', 'w') as f:
    csrf_time_limit_found = False
    for line in lines:
        if line.startswith('WTF_CSRF_EXEMPT_LIST'):
            f.write("WTF_CSRF_EXEMPT_LIST = ['oauth-authorized']\n")
        elif line.strip() == 'WTF_CSRF_TIME_LIMIT = None':
            f.write(line)
            csrf_time_limit_found = True
        elif csrf_time_limit_found and line.strip() and not line.startswith('WTF_CSRF_SSL_STRICT'):
            f.write('WTF_CSRF_SSL_STRICT = False  # Cloudflare Tunnel termina SSL\n')
            f.write(line)
            csrf_time_limit_found = False
        else:
            f.write(line)

print('CSRF config atualizado!')
