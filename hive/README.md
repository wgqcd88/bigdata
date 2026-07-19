### 导入镜像到acr
```
az acr import -n <acr_name> \
	--source ghcr.io/wgqcd88/hive-metastore:3.1.3-20260719 \
	--image azure/hive-metastore:3.1.3-20260719
```

### 创建 helm hive-metastore-values.yaml
```
namespace: hive
image:
  repository: <acr_name>.azurecr.io/azure/hive-metastore
  tag: 3.1.3-20260719
  pullSecrets:
    - name: image_pull
nodeSelector: 
  hive-metastore: support
database:
  url: "jdbc:mysql://<mysql_host>:3306/<database_name>?createDatabaseIfNotExist=true&useSSL=true&requireSSL=true&serverTimezone=UTC&characterEncoding=UTF-8&rewriteBatchedStatements=true&connectTimeout=10000&socketTimeout=60000"
  username: "<dababase_username>"
  password: "<database_password>"
azure:
  clientId: "<mi_clientId>"
  tenantId: "<mi_tenantId>"
  hnsEnabled: "true"
  workloadIdentity:
    enabled: true
serviceAccount:
  name: hive-metastore-sa
```
### 内置数据库跨可用区存储
启用内置 MySQL 或 PostgreSQL 时，可启用 Azure Disk CSI 的 `Premium_ZRS`
StorageClass。默认的内置数据库 PVC 会使用 `hive-metastore-zrs`：
```
storageClass:
  enabled: true
```
`Premium_ZRS` 要求 AKS 区域和订阅支持区域冗余托管磁盘。

### 配置 Warehouse 目录
设置 `metastore.warehouseDir` 会覆盖 `hive-site.xml` 中的
`hive.metastore.warehouse.dir`；留空则使用 `/opt/hive/data/warehouse`：
```
metastore:
  warehouseDir: "abfss://<container>@<account>.dfs.core.windows.net/warehouse"
```

### 安装hive metastore
```
helm upgrade --install hive-metastore  \
	-n hive --create-namespace  \
	oci://ghcr.io/wgqcd88/charts/hive-metastore \
	--version 3.1.3-20260719 \
  -f hive-metastore-values.yaml
```