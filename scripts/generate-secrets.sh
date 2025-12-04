#!/bin/bash
set -e

# Kubernetes Secrets Generator
# Generates secrets.yml with random passwords

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${SCRIPT_DIR}/../kubernetes/base/secrets.yml"

# Generate random password
gen_password() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

# Encode to base64
b64() {
    echo -n "$1" | base64
}

echo "Generating Kubernetes secrets..."

# Generate passwords
PG_PASSWORD=$(gen_password)
SHLINK_DB_PASSWORD=$(gen_password)
DOCMOST_SECRET=$(openssl rand -hex 32)
GRAFANA_PASSWORD=$(gen_password)
REGISTRY_SECRET=$(openssl rand -hex 32)

# Docmost database URL
DOCMOST_DB_URL="postgresql://docmost:${SHLINK_DB_PASSWORD}@postgresql.database.svc.cluster.local:5432/docmost"

cat > "$SECRETS_FILE" << EOF
---
# Auto-generated Kubernetes Secrets
# Generated at: $(date -Iseconds)
# DO NOT commit this file to git!

# PostgreSQL
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secrets
  namespace: database
type: Opaque
data:
  username: $(b64 "postgres")
  password: $(b64 "$PG_PASSWORD")
---
# Shlink
apiVersion: v1
kind: Secret
metadata:
  name: shlink-secrets
  namespace: apps
type: Opaque
data:
  db-user: $(b64 "shlink")
  db-password: $(b64 "$SHLINK_DB_PASSWORD")
---
# Docmost
apiVersion: v1
kind: Secret
metadata:
  name: docmost-secrets
  namespace: devops
type: Opaque
data:
  database-url: $(b64 "$DOCMOST_DB_URL")
  app-secret: $(b64 "$DOCMOST_SECRET")
---
# Grafana
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secrets
  namespace: monitoring
type: Opaque
data:
  admin-user: $(b64 "admin")
  admin-password: $(b64 "$GRAFANA_PASSWORD")
---
# Registry
apiVersion: v1
kind: Secret
metadata:
  name: registry-secrets
  namespace: registry
type: Opaque
data:
  http-secret: $(b64 "$REGISTRY_SECRET")
EOF

echo "Secrets generated: $SECRETS_FILE"
echo ""
echo "=== Generated Passwords (save these!) ==="
echo "PostgreSQL:  $PG_PASSWORD"
echo "Shlink DB:   $SHLINK_DB_PASSWORD"
echo "Grafana:     $GRAFANA_PASSWORD"
echo ""
echo "Apply with: kubectl apply -f $SECRETS_FILE"
