#!/bin/bash
cd /home/sbadakhc/src/github.com/xencon/aixcl
git checkout -b feature/service-control-and-readme-update
git add aixcl bash_completion.sh README.md
git commit -m "feat: Add granular service control and update README

- Add llm-council to ALL_SERVICES array for individual service control
- Update logs function to support all services dynamically (including loki, promtail)
- Update stop function to dynamically check all services
- Add all services to bash completion (llm-council, loki, promtail)
- Add service command completion for start/stop/restart actions
- Rewrite README to be concise and focused on quick start, troubleshooting, and services"
git log --oneline -1
