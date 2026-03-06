# Nextcloud パフォーマンス問題と改善策

## 現状の問題

Nextcloudが非常に遅い。原因はNFSストレージがボトルネックになっている可能性が高い。

### 現在の構成

| コンポーネント | ストレージ | 問題点 |
|---------------|-----------|--------|
| Nextcloud | NFS (nextcloud-data) | アプリ全体がNFS上 |
| PostgreSQL | NFS (nextcloud-postgres) | DBがNFS上は致命的 |
| Redis | NFS (nextcloud-redis) | キャッシュがNFS上は本末転倒 |

## 原因分析

### NFSの特性
- **レイテンシ**: ネットワーク経由のため、ローカルディスクより遅い
- **小さいファイルの大量アクセス**: PHPアプリは多数の小さいファイルを読み込む
- **データベース**: ランダムI/Oが多いDBはNFSに向かない
- **同期書き込み**: デフォルトでsync mountのため書き込みが遅い

### 確認コマンド

```bash
# NFS接続のレイテンシ確認
time kubectl exec -n nextcloud -l app=nextcloud -- ls /var/www/html

# NFSサーバー(pochama)の負荷確認
ssh pochama "iostat -x 1 3"

# Pod内からのディスクI/O確認
kubectl exec -n nextcloud -l app=nextcloud -- dd if=/dev/zero of=/var/www/html/testfile bs=1M count=100 oflag=direct
```

## 改善策

### 1. PostgreSQL/Redisをローカルストレージに移動（推奨）

データベースとキャッシュはNFSに置くべきではない。

**変更内容:**
- PostgreSQL: `emptyDir` または `hostPath` を使用
- Redis: `emptyDir` を使用（キャッシュなので永続化不要）
- Nextcloud: ユーザーデータのみNFS

**メリット:**
- DBのI/O性能が大幅改善
- Redisのレイテンシ改善

**デメリット:**
- Podが別ノードに移動するとデータ喪失（PostgreSQL）
- 対策: `nodeSelector` でノード固定 or StatefulSet使用

### 2. NFSマウントオプションの最適化

StorageClassまたはPVのマウントオプションを変更:

```yaml
mountOptions:
  - nfsvers=4.1
  - async          # 非同期書き込み（データ損失リスクあり）
  - noatime        # アクセス時刻更新を無効化
  - nodiratime     # ディレクトリのアクセス時刻更新を無効化
  - rsize=1048576  # 読み取りブロックサイズ
  - wsize=1048576  # 書き込みブロックサイズ
```

### 3. Nextcloudのキャッシュ設定強化

`config.php` に追加:

```php
'memcache.local' => '\\OC\\Memcache\\APCu',
'memcache.distributed' => '\\OC\\Memcache\\Redis',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'filelocking.enabled' => true,
```

### 4. PHP OPcacheの最適化

Nextcloud Podに環境変数を追加:

```yaml
env:
  - name: PHP_MEMORY_LIMIT
    value: "512M"
  - name: PHP_UPLOAD_LIMIT
    value: "512M"
```

### 5. アプリケーションコードをemptyDirに配置

Nextcloudのアプリケーションコードは読み取り専用なので、initContainerでコピー:

```yaml
initContainers:
  - name: copy-app
    image: nextcloud:28-apache
    command: ['cp', '-r', '/var/www/html/.', '/app/']
    volumeMounts:
      - name: app-code
        mountPath: /app

containers:
  - name: nextcloud
    volumeMounts:
      - name: app-code
        mountPath: /var/www/html
      - name: nextcloud-data
        mountPath: /var/www/html/data  # ユーザーデータのみNFS
```

## 推奨アクション

### Phase 1: 即効性のある改善
1. PostgreSQLを `emptyDir` + `nodeSelector` に変更
2. Redisを `emptyDir` に変更
3. Deployment再作成

### Phase 2: 追加最適化
1. NFSマウントオプション最適化
2. Nextcloudキャッシュ設定
3. PHP OPcache設定

### Phase 3: 本格対応（将来）
1. PostgreSQLをマネージドDB（OCI DBaaS）に移行
2. 専用ブロックストレージ（OCI Block Volume）の導入
3. Longhorn/Rook-Cephなどの分散ストレージ検討

## 参考情報

- [Nextcloud Server Tuning](https://docs.nextcloud.com/server/latest/admin_manual/installation/server_tuning.html)
- [NFS Best Practices for Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/#nfs)
