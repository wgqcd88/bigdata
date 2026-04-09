# StarRocks on AKS

部署 StarRocks (FE + CN) 作为 Lakehouse 查询引擎，通过 Hive External Catalog 查询 Azure ABFS 上的数据。

## 架构

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌────────────┐
│  MySQL CLI  │────▶│  FE (1 pod)  │────▶│  CN (2 pods)     │────▶│ Azure ABFS │
│  Port 9030  │     │  Query Plan  │     │  Compute Only    │     │  wgqsajw   │
└─────────────┘     └──────┬───────┘     └──────────────────┘     └────────────┘
                           │
                    ┌──────▼───────┐
                    │ Hive Metastore│
                    │ (thrift:9083) │
                    └──────────────┘
```

- **FE**: 1 副本，负责 SQL 解析、查询规划、元数据管理
- **CN**: 2 副本，无状态计算节点，负责查询执行
- **无 BE**: 不存储本地数据，纯 Lakehouse 查询模式

## 部署

### 前置条件

- StarRocks Operator 已安装（CRD + Operator）

```bash
# 安装 CRD
kubectl apply --server-side -f https://raw.githubusercontent.com/StarRocks/starrocks-kubernetes-operator/main/deploy/starrocks.com_starrocksclusters.yaml

# 安装 Operator
kubectl apply -f https://raw.githubusercontent.com/StarRocks/starrocks-kubernetes-operator/main/deploy/operator.yaml
```

### 部署集群

```bash
kubectl apply -f starrocks-cluster.yaml
```

### 验证

```bash
# 检查集群状态
kubectl get src -n starrocks

# 连接 FE
kubectl exec -n starrocks starrocks-fe-0 -- mysql -h 127.0.0.1 -P 9030 -u root -e "SHOW FRONTENDS\G"

# 查看 CN 节点
kubectl exec -n starrocks starrocks-fe-0 -- mysql -h 127.0.0.1 -P 9030 -u root -e "SHOW COMPUTE NODES\G"
```

## Hive External Catalog

创建 Hive Catalog（连接 Hive Metastore + Azure ABFS Shared Key 认证）：

```sql
CREATE EXTERNAL CATALOG hive_catalog
PROPERTIES (
    'type' = 'hive',
    'hive.metastore.type' = 'hive',
    'hive.metastore.uris' = 'thrift://hive-metastore.hive.svc.cluster.local:9083',
    'azure.adls2.storage_account' = 'wgqsajw',
    'azure.adls2.shared_key' = '<storage-account-key>'
);
```

查询示例：

```sql
-- 设置使用 CN 节点（无 BE 时必需）
SET GLOBAL prefer_compute_node = true;
SET GLOBAL use_compute_nodes = -1;

-- 查询 Hive 数据
SELECT * FROM hive_catalog.trino_test.demo;
```

## 已知问题及修复

### wildfly-openssl SIGSEGV

StarRocks CN 的 Java 连接器使用 wildfly-openssl 访问 HTTPS（Azure ABFS），
与容器内 OpenSSL 库不兼容导致 `SSL_CTX_new_ex` SIGSEGV 崩溃。

**修复**: 在 cn.conf 中禁用 wildfly-openssl native，强制使用 Java JSSE：

```
JAVA_OPTS="-Dorg.wildfly.openssl.path=invalid -Dorg.wildfly.openssl.path.ssl=invalid -Dorg.wildfly.openssl.path.crypto=invalid"
```

### CN-only 模式

无 BE 节点时，需设置全局变量让查询路由到 CN：

```sql
SET GLOBAL prefer_compute_node = true;
SET GLOBAL use_compute_nodes = -1;
```
