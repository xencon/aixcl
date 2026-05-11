# HashiCorp Vault production server configuration
# Used when running Vault in server mode (not -dev).
# Secrets are persisted to the aixcl-vault-data volume at /vault/file.

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  # TLS is disabled: Vault binds to 127.0.0.1 (host network) and is
  # not reachable from outside the host. Compensating control: host firewall.
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8200"
ui       = true
