#!/bin/bash
# Test database connection inside the Docker container

set -e

echo "Testing PostgreSQL Database Connection in Container"
echo "==================================================="

# Check if we're in a container
if [ ! -f /.dockerenv ]; then
    echo "This script should be run inside the Docker container"
    echo "Run: docker exec -it llm-council bash test_db_in_container.sh"
    exit 1
fi

# Run the Python test script
cd /app
python3 test_db_connection.py

