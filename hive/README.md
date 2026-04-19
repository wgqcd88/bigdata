### 导入镜像到acr
```
az acr import -n <acr_name> \
	--source ghcr.io/wgqcd88/hive-metastore:3.1.3-20260407 \
	--image azure/hive-metastore:3.1.3-20260407 
```

### 创建helm values.yaml
```
image:
  repository: <acr_name>.azurecr.io/azure/hive-metastore
  tag: 3.1.3-20260407
nodeSelector: {}
database:
  url: "jdbc:mysql://<mysql_host>:3306/<database_name>?createDatabaseIfNotExist=true&useSSL=true&requireSSL=true&serverTimezone=UTC&characterEncoding=UTF-8&rewriteBatchedStatements=true&connectTimeout=10000&socketTimeout=60000"
  username: "<dababase_username>"
  password: "<database_password>"
azure:
  clientId: "<mi_clientId>"
  tenantId: "<mi_tenantId>"
```
### 安装hive metastore
```
helm upgrade --install hive-metastore  \
	-n hive --create-namespace  \
	oci://ghcr.io/wgqcd88/charts/hive-metastore \
	--version 3.1.3-20260419 
```