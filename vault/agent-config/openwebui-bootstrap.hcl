pid_file = "/tmp/vault-agent-openwebui-bootstrap.pid"

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
      path = "/tmp/vault-token-openwebui-bootstrap"
    }
  }
}

template {
  destination = "/run/secrets/openwebui-password"
  contents = <<-EOT
    {{- with secret "kv/data/bootstrap/openwebui" -}}
    {{ .data.data.password }}
    {{- end }}
  EOT
  command = "sh -c 'echo Open WebUI bootstrap password updated'"
}
