pid_file = "/tmp/vault-agent-openwebui.pid"

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
      path = "/tmp/vault-token-openwebui"
    }
  }
}

template {
  destination = "/run/secrets/openwebui-db-creds"
  contents = <<-EOT
    {{- with secret "database/creds/aixcl-app" -}}
    postgresql://{{ .Data.username }}:{{ .Data.password }}@127.0.0.1:5432/webui
    {{- end }}
  EOT
  command = "sh -c 'echo Credentials updated for Open WebUI'"
}
