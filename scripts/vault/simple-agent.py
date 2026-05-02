#!/usr/bin/env python3
"""
Vault Agent for PostgreSQL Exporter
Generates credentials from Vault and writes to file
"""

import json
import urllib.request
import time
import os

VAULT_ADDR = os.environ.get('VAULT_ADDR', 'http://127.0.0.1:8200')
VAULT_TOKEN = os.environ.get('VAULT_TOKEN', 'aixcl-dev-token')

def log(msg):
    print(f"[Vault Agent] {msg}", flush=True)

def get_credentials():
    """Get credentials from Vault"""
    url = f"{VAULT_ADDR}/v1/database/creds/aixcl-app"
    req = urllib.request.Request(url)
    req.add_header('X-Vault-Token', VAULT_TOKEN)
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            return {
                'username': data['data']['username'],
                'password': data['data']['password']
            }
    except Exception as e:
        log(f"Error: {e}")
        return None

def main():
    os.makedirs('/tmp/vault-secrets', exist_ok=True)
    
    while True:
        creds = get_credentials()
        if creds:
            with open('/tmp/vault-secrets/pgexporter-creds', 'w') as f:
                f.write(f"postgresql://{creds['username']}:{creds['password']}@127.0.0.1:5432/webui?sslmode=disable")
            log(f"Generated credentials for {creds['username']}")
        
        # Rotate every 45 minutes
        time.sleep(2700)

if __name__ == '__main__':
    main()
