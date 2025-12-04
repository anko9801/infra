# Infrastructure

Home lab infrastructure management with Terraform, Ansible, and Kubernetes.

## Structure

```
infra/
├── terraform/        # OCI infrastructure provisioning
├── ansible/          # Server configuration management
├── kubernetes/       # K8s manifests
├── docker/           # Docker Compose (pochama)
├── scripts/          # Utility scripts
└── docs/             # Documentation
```

## Quick Start

```bash
# Install requirements
brew install terraform ansible kubectl

# Initialize
./scripts/setup.sh

# Deploy infrastructure
cd terraform && terraform apply

# Configure servers
cd ../ansible && ansible-playbook playbooks/common.yml
```

## Components

### Applications
- **Home Assistant** - Home automation
- **Docmost** - Documentation wiki
- **Shlink** - URL shortener
- **Registry** - Private Docker registry

### Monitoring
- **Prometheus** - Metrics
- **Grafana** - Visualization
- **Loki** - Logs

## Documentation

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.
