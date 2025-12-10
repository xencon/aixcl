#!/bin/bash
docker exec postgres psql -U admin -d webui -c "SELECT id, title, source FROM chat WHERE source = 'continue' ORDER BY created_at DESC LIMIT 3;"

