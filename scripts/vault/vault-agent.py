#!/usr/bin/env python3
"""
Vault Agent for AIXCL
Generates and rotates PostgreSQL credentials from Vault

Usage:
    python3 vault-agent.py [role-name]
    
Environment:
    VAULT_ADDR - Vault server URL (default: http://127.0.0.1:8200)
    VAULT_TOKEN - Vault token (default: aixcl-dev-token)
"""

import os
import sys
import time
import json
import urllib.request
import urllib.error

VAULT_ADDR = os.environ.get('VAULT_ADDR', 'http://127.0.0.1:8200')
VAULT_TOKEN = os.environ.get('VAULT_TOKEN', 'aixcl-dev-token')
SECRETS_DIR = '/run/secrets'


def log(msg):
    print(f"[Vault Agent] {msg}", flush=True)


def wait_for_vault():
    """Wait for Vault to be ready"""
    log("Waiting for Vault...")
    while True:
        try:
            req = urllib.request.Request(f"{VAULT_ADDR}/v1/sys/health")
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    log("Vault is ready")
                    return True
        except:
            pass
        time.sleep(2)


def get_credentials(role_name):
    """Get dynamic credentials from Vault"""
    url = f"{VAULT_ADDR}/v1/database/creds/{role_name}"
    req = urllib.request.Request(url)
    req.add_header('X-Vault-Token', VAULT_TOKEN)
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            return {
                'username': data['data']['username'],
                'password': data['data']['password'],
                'lease_id': data['lease_id']
            }
    except Exception as e:
        log(f"Failed to get credentials: {e}")
        return None


def write_credentials(username, password):
    """Write credentials to files"""
    os.makedirs(SECRETS_DIR, exist_ok=True)
    
    # Write full connection string
    with open(f"{SECRETS_DIR}/database-creds", 'w') as f:
        f.write(f"postgresql://{username}:{password}@127.0.0.1:5432/webui?sslmode=disable")
    
    # Write separate username/password files
    with open(f"{SECRETS_DIR}/db-username", 'w') as f:
        f.write(username)
    
    with open(f"{SECRETS_DIR}/db-password", 'w') as f:
        f.write(password)
    
    log(f"Written credentials for {username}")


def main():
    role_name = sys.argv[1] if len(sys.argv) > 1 else 'aixcl-app'
    
    wait_for_vault()
    
    log(f"Starting credential generation for role: {role_name}")
    log(f"Credentials will be written to {SECRETS_DIR}")
    
    while True:
        creds = get_credentials(role_name)
        if creds:
            write_credentials(creds['username'], creds['password'])
            log(f"Generated lease: {creds['lease_id']}")
        else:
            log("Failed to generate credentials, retrying in 30s")
            time.sleep(30)
            continue
        
        # Rotate every 45 minutes (before 1h expiry)
        log("Sleeping for 45 minutes before next rotation...")
        time.sleep(2700)


if __name__ == '__main__':
    main()
