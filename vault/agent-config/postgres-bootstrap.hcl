pid_file = "/tmp/vault-agent-postgres-bootstrap.pid"

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
      path = "/tmp/vault-token-postgres-bootstrap"
    }
  }
}

template {
  destination = "/run/secrets/postgres-password"
  contents = <<-EOT
    {{- with secret "kv/data/bootstrap/postgres" -}}
    {{ .data.data.password }}
    {{- end }}
  EOT
  command = "sh -c 'echo PostgreSQL bootstrap password updated'"
}
