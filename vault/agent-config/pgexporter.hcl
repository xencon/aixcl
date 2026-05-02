pid_file = "/tmp/vault-agent-pgexporter.pid"

vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method "token" {
    config = {
      token = "aixcl-dev-token"
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token-pgexporter"
    }
  }
}

template {
  destination = "/run/secrets/pgexporter-creds"
  contents = <<-EOT
    {{- with secret "database/creds/aixcl-app" -}}
    DATA_SOURCE_NAME=postgresql://{{ .Data.username }}:{{ .Data.password }}@127.0.0.1:5432/webui?sslmode=disable
    {{- end }}
  EOT
  command = "sh -c 'pkill -HUP postgres_exporter || true'"
}
