# トラブルシューティングメモ

## 2025-12-04: Nextcloudデプロイ時の問題

### 問題1: NFS接続タイムアウト

**症状:**
- PVCがPendingのまま
- `showmount -e 10.0.0.10` が "RPC: Unable to receive" で失敗
- `nc -zv 10.0.0.10 2049` が "No route to host" で失敗
- ただし `ping 10.0.0.10` は成功

**原因:**
OCI Ubuntuイメージのデフォルトiptablesに以下のREJECTルールが存在:
```
REJECT all -- 0.0.0.0/0 0.0.0.0/0 reject-with icmp-host-prohibited
```
このルールがUFWルールより前に評価され、SSH/ICMP/established以外の全トラフィックをブロック。

**解決策:**
Ansibleで全ノードからREJECTルールを削除:
```bash
ansible-playbook playbooks/oci-iptables-fix.yml
```

**補足:**
- TerraformのSecurity Listでは既にVCN内通信(10.0.0.0/16)を許可済みだった
- 問題はOS内のiptablesレイヤーだった

---

### 問題2: DNS解決失敗

**症状:**
- NextcloudがPostgreSQLに接続できない
- ログに `could not translate host name "postgres" to address: Temporary failure in name resolution`

**原因:**
CoreDNSがKubernetes API (10.96.0.1:443) に接続できていなかった:
```
dial tcp 10.96.0.1:443: connect: no route to host
```

**解決策:**
kube-proxyとCoreDNSを再起動:
```bash
kubectl rollout restart daemonset kube-proxy -n kube-system
kubectl rollout restart deployment coredns -n kube-system
```

---

### 問題3: PVC Pending

**症状:**
- `kubectl get pvc -n nextcloud` で全てPending

**原因:**
問題1（NFS接続タイムアウト）の結果、CSI DriverがNFSサーバーにマウントできなかった。

**解決策:**
問題1を解決後、自動的にBoundになった。

---

## まとめ

| 問題 | 症状 | 原因 | 解決策 |
|------|------|------|--------|
| NFS接続タイムアウト | PVC Pending, showmount失敗 | OCI iptables REJECTルール | Ansibleでルール削除 |
| DNS解決失敗 | Postgres接続エラー | CoreDNSがAPI接続不可 | kube-proxy/CoreDNS再起動 |
| PVC Pending | Boundにならない | NFS接続不可 | 上記解決で自動復旧 |

## 教訓

1. **OCIのデフォルトiptables**: Security Listで許可してもOS内のiptablesでブロックされることがある
2. **pingが通ってもポートが開いているとは限らない**: ICMPとTCP/UDPは別
3. **CoreDNSのログ確認**: Pod間通信の問題はまずDNSを疑う
