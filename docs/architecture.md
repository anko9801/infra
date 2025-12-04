# Infrastructure Architecture

## Overview

OCI Free Tier 4ノード + 自宅 GPU サーバー構成

```
┌─────────────────────────────────────────────────────────────────┐
│                      OCI VCN (10.0.0.0/16)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │
│  │   pikachu     │  │   metamon     │  │    bracky     │        │
│  │  1 OCPU/6GB   │  │  1 OCPU/6GB   │  │  1 OCPU/6GB   │        │
│  │               │  │               │  │               │        │
│  │ k8s control   │  │ ── DevOps ──  │  │ ── Apps ────  │        │
│  │ plane         │  │ Registry      │  │ Home Assistant│        │
│  │               │  │ Prometheus    │  │ PostgreSQL    │        │
│  │ etcd          │  │ Grafana       │  │ Redis         │        │
│  │ CoreDNS       │  │ Loki          │  │ Shlink        │        │
│  │ metrics-server│  │ Docmost       │  │ 自作アプリ    │        │
│  │               │  │               │  │               │        │
│  └───────────────┘  └───────────────┘  └───────────────┘        │
│                                                                 │
│  ┌───────────────┐                                              │
│  │   pochama     │  ← k8s 外（Docker Compose）                  │
│  │  1 OCPU/6GB   │                                              │
│  │               │                                              │
│  │ Tailscale     │  VPN アクセス                                │
│  │ Traefik       │  リバースプロキシ                            │
│  │ NFS Server    │  k8s の PV 用                                │
│  │ Nextcloud     │  ファイル同期                                │
│  │               │                                              │
│  └───────────────┘                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

自宅
┌─────────────────┐
│   GPU サーバー  │
│   RTX 3070 Ti   │
│                 │
│ Ollama          │  LLM 推論
│ Open WebUI      │  チャット UI
│ Tailscale       │  VPN 接続
│                 │
└─────────────────┘
```

## Node Roles

| Node | Role | Label | Workloads |
|------|------|-------|-----------|
| pikachu | Control Plane | `node-role.kubernetes.io/control-plane` | etcd, API server, CoreDNS |
| metamon | DevOps Worker | `role=devops` | Registry, Prometheus, Grafana, Loki, Docmost |
| bracky | Apps Worker | `role=apps` | Home Assistant, PostgreSQL, Redis, Shlink |
| pochama | Infra (Docker) | - | Tailscale, Traefik, NFS, Nextcloud |

## Network Architecture

```
Internet
    │
    ▼
┌─────────┐
│ pochama │ ← Public IP, TLS 終端
│ Traefik │
└────┬────┘
     │ NodePort routing
     │
     ├──────────────────────────────────────┐
     │                                      │
     ▼                                      ▼
┌─────────────────┐                ┌─────────────────┐
│    metamon      │                │     bracky      │
│  (DevOps Node)  │                │   (Apps Node)   │
├─────────────────┤                ├─────────────────┤
│ :30300 Grafana  │                │ :30123 HA       │
│ :30301 Docmost  │                │ :30080 Shlink   │
│ :30500 Registry │                │                 │
└─────────────────┘                └─────────────────┘

Tailscale Mesh Network (100.x.x.x)
┌────────────────────────────────────────────┐
│  pochama ←→ GPU Server ←→ k8s nodes       │
└────────────────────────────────────────────┘
```

## Storage Architecture

```
pochama (NFS Server)
├── /srv/nfs/k8s/           ← k8s PV 用
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   ├── home-assistant/
│   ├── postgresql/
│   ├── redis/
│   ├── docmost/
│   └── registry/
│
└── /srv/nfs/nextcloud/     ← Nextcloud データ
```

## Kubernetes Namespaces

| Namespace | Node | Description |
|-----------|------|-------------|
| `apps` | bracky | User-facing applications |
| `database` | bracky | PostgreSQL, Redis |
| `devops` | metamon | Docmost |
| `monitoring` | metamon | Prometheus, Grafana, Loki |
| `registry` | metamon | Docker Registry |

## Service URLs

| Service | URL | Node |
|---------|-----|------|
| Home Assistant | `ha.example.com` | bracky |
| Grafana | `grafana.example.com` | metamon |
| Docmost | `docs.example.com` | metamon |
| Shlink | `s.example.com` | bracky |
| Registry | `registry.example.com` | metamon |
| Nextcloud | `cloud.example.com` | pochama |
| Traefik Dashboard | `traefik.example.com` | pochama |

## Deployment Flow

```
1. Terraform: OCI リソース作成
   └── terraform apply

2. Ansible: サーバー初期設定
   ├── common.yml  → 全ノード共通設定
   ├── k8s.yml     → pikachu, metamon, bracky
   └── infra.yml   → pochama (Docker)

3. Kubernetes: ワークロードデプロイ
   ├── base/       → Namespace, StorageClass
   ├── apps/       → bracky へデプロイ
   └── monitoring/ → metamon へデプロイ

4. Docker Compose: pochama サービス
   └── docker compose up -d
```

## Security

- **Network**: VCN Security List で必要なポートのみ許可
- **VPN**: Tailscale で内部通信暗号化
- **TLS**: Let's Encrypt 自動証明書 (Traefik)
- **Secrets**: Kubernetes Secrets で機密情報管理
- **Firewall**: UFW で各ノードを保護

## Resource Summary

| Node | CPU | Memory | Disk | Network |
|------|-----|--------|------|---------|
| pikachu | 1 OCPU | 6 GB | 50 GB | Public IP |
| metamon | 1 OCPU | 6 GB | 50 GB | Public IP |
| bracky | 1 OCPU | 6 GB | 50 GB | Public IP |
| pochama | 1 OCPU | 6 GB | 50 GB | Public IP |
| **Total** | **4 OCPU** | **24 GB** | **200 GB** | - |

*OCI Free Tier: 4 OCPU / 24 GB Memory (ARM)*
