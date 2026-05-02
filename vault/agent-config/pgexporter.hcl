pid_file = "/tmp/vault-agent-pgexporter.pid"

vault {
  address = "http://127.0.0.1:8200"
}

template {
  destination = "/tmp/vault-secrets/pgexporter-creds"
  contents = <<-EOT
    {{- with secret "database/creds/aixcl-app" -}}
    postgresql://{{ .Data.username }}:{{ .Data.password }}@127.0.0.1:5432/webui?sslmode=disable
    {{- end }}
  EOT
  command = "sh -c 'pkill -HUP postgres_exporter || true'"
}
