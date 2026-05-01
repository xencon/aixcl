pid_file = "/tmp/vault-agent.pid"

vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path = "/etc/vault/role-id"
      secret_id_file_path = "/etc/vault/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token"
    }
  }
}

template {
  destination = "/run/secrets/database-creds"
  contents = <<-EOT
    {{- with secret "database/creds/aixcl-app" -}}
    postgresql://{{ .Data.username }}:{{ .Data.password }}@127.0.0.1:5432/webui?sslmode=require
    {{- end }}
  EOT
  command = "sh -c 'pg_isready -q || echo \"Database connection failed\"'"
}

# Rotate credentials every 50 minutes (before 1h TTL expires)
template {
  destination = "/run/secrets/.rotation-timer"
  contents = "{{ timestamp }}"
  command = "sleep 3000 && kill -HUP $(cat /tmp/vault-agent.pid)"
}
