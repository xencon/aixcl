# HashiCorp Vault production server configuration
# Used when running Vault in server mode (not -dev).
# Secrets are persisted to the aixcl-vault-data volume at /vault/file.

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  # TLS is disabled: the listener is bound to loopback only, so it is not
  # reachable from outside the host regardless of firewall state. Every
  # consumer in this repo (vault-agent sidecars, bootstrap scripts, the
  # aixcl CLI) already connects via 127.0.0.1 -- confirmed by grepping
  # every VAULT_ADDR reference in the repo, none use a non-loopback
  # address (#1996). Compensating control: host firewall, defense in depth.
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8200"
ui       = true

# mlock prevents memory being swapped to disk but requires elevated kernel
# privileges. Rootless Podman and WSL do not grant these, so we disable it.
# Compensating control: the host filesystem is the security boundary here,
# not kernel memory locking.
disable_mlock = true
