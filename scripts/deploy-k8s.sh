#!/bin/bash
set -e

# Kubernetes deployment script
# Applies manifests in correct order

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/../kubernetes"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check kubectl
command -v kubectl >/dev/null 2>&1 || error "kubectl not found"

# Check cluster connection
kubectl cluster-info >/dev/null 2>&1 || error "Cannot connect to Kubernetes cluster"

log "Connected to cluster: $(kubectl config current-context)"

# Deploy function
deploy() {
    local file=$1
    local name=$(basename "$file")

    if [ -f "$file" ]; then
        log "Applying: $name"
        kubectl apply -f "$file"
    else
        warn "Not found: $file"
    fi
}

echo ""
log "=== Phase 1: System Components ==="

# NFS CSI Driver
deploy "${K8S_DIR}/system/nfs-csi/nfs-csi-driver.yml"
log "Waiting for NFS CSI driver..."
kubectl wait --for=condition=available --timeout=120s deployment/csi-nfs-controller -n kube-system || warn "CSI controller not ready"

echo ""
log "=== Phase 2: Base Configuration ==="

# Namespaces
deploy "${K8S_DIR}/base/namespaces.yml"

# Storage Class
deploy "${K8S_DIR}/base/storage-class.yml"

# Secrets (if exists)
if [ -f "${K8S_DIR}/base/secrets.yml" ]; then
    deploy "${K8S_DIR}/base/secrets.yml"
else
    warn "secrets.yml not found. Run: ./scripts/generate-secrets.sh"
fi

echo ""
log "=== Phase 3: Database Layer ==="

# PostgreSQL
deploy "${K8S_DIR}/apps/postgresql/deployment.yml"
log "Waiting for PostgreSQL..."
kubectl wait --for=condition=ready --timeout=180s pod -l app=postgresql -n database || warn "PostgreSQL not ready"

# Redis
deploy "${K8S_DIR}/apps/redis/deployment.yml"
log "Waiting for Redis..."
kubectl wait --for=condition=ready --timeout=120s pod -l app=redis -n database || warn "Redis not ready"

echo ""
log "=== Phase 4: Monitoring Stack (metamon) ==="

deploy "${K8S_DIR}/monitoring/prometheus/deployment.yml"
deploy "${K8S_DIR}/monitoring/loki/deployment.yml"
deploy "${K8S_DIR}/monitoring/grafana/deployment.yml"

echo ""
log "=== Phase 5: DevOps Tools (metamon) ==="

deploy "${K8S_DIR}/apps/registry/deployment.yml"
deploy "${K8S_DIR}/apps/docmost/deployment.yml"

echo ""
log "=== Phase 6: Applications (bracky) ==="

deploy "${K8S_DIR}/apps/home-assistant/deployment.yml"
deploy "${K8S_DIR}/apps/shlink/deployment.yml"

echo ""
log "=== Phase 7: NodePort Services ==="

deploy "${K8S_DIR}/base/nodeport-services.yml"

echo ""
log "=== Deployment Complete ==="
echo ""

# Show status
log "Pod Status:"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | head -20 || log "All pods running"

echo ""
log "Services:"
kubectl get svc -A | grep -E "NodePort|LoadBalancer" | head -10

echo ""
log "Next steps:"
echo "  1. Verify pods: kubectl get pods -A"
echo "  2. Check logs: kubectl logs -n <namespace> <pod>"
echo "  3. Update Traefik with NodePort IPs"
