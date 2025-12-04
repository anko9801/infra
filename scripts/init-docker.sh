#!/bin/bash
set -e

# Docker/Traefik initialization script for pochama
# Run this once after first deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../docker"

echo "=== Initializing Docker environment for pochama ==="

# Create required directories
echo "Creating directories..."
mkdir -p "${DOCKER_DIR}/traefik/dynamic"
mkdir -p "${DOCKER_DIR}/tailscale/state"
mkdir -p "${DOCKER_DIR}/nextcloud/config"

# Create acme.json with correct permissions
ACME_FILE="${DOCKER_DIR}/traefik/acme.json"
if [ ! -f "$ACME_FILE" ]; then
    echo "Creating acme.json..."
    touch "$ACME_FILE"
    chmod 600 "$ACME_FILE"
    echo "Created: $ACME_FILE"
else
    echo "acme.json already exists"
    # Ensure correct permissions
    chmod 600 "$ACME_FILE"
fi

# Create .env from example if not exists
ENV_FILE="${DOCKER_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "${DOCKER_DIR}/.env.example" ]; then
        echo "Creating .env from example..."
        cp "${DOCKER_DIR}/.env.example" "$ENV_FILE"
        echo "Created: $ENV_FILE"
        echo "WARNING: Edit $ENV_FILE with your actual values!"
    fi
else
    echo ".env already exists"
fi

# Create Docker network if not exists
echo "Creating Docker network..."
docker network create web 2>/dev/null || echo "Network 'web' already exists"

# Verify structure
echo ""
echo "=== Directory structure ==="
find "${DOCKER_DIR}" -type f -name "*.yml" -o -name "*.json" -o -name ".env*" 2>/dev/null | sort

echo ""
echo "=== Initialization complete ==="
echo ""
echo "Next steps:"
echo "1. Edit ${DOCKER_DIR}/.env with your values"
echo "2. cd ${DOCKER_DIR}"
echo "3. docker compose up -d"
