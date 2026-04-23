### 创建spark-values.yaml
```
namespace: spark
image:
  repository: ghcr.io/wgqcd88/spark
  tag: "3.5.4-2026041416"
timezone: Asia/Shanghai
serviceAccount:
  name: spark
azureStorageAuth:
  "spark.hadoop.fs.azure.account.oauth2.client.id":              "<mi_client_id>"
  "spark.hadoop.fs.azure.account.oauth2.msi.tenant":             "<mi_tenant_id>"
commonSparkConf:
  "spark.eventLog.dir":                                          "abfs://<container_name>@<account_name>.dfs.core.windows.net/spark/eventlogs"
  "spark.history.fs.logDirectory":                               "abfs://<container_name>@<account_name>.dfs.core.windows.net/spark/eventlogs"
  "spark.sql.warehouse.dir":                                     "abfs://<container_name>@<account_name>.dfs.core.windows.net/hive/warehouse"
  "spark.hadoop.hive.metastore.uris":                            "thrift://hive-metastore.hive.svc:9083"
  "spark.storage.decommission.fallbackStorage.path":             "abfs://<container_name>@<account_name>.dfs.core.windows.net/decommission/"
# ── Spark Thrift Server ──────────────────────────────────────────
thriftServer:
  enabled: true
  nodeSelector:
    spark-thrift-server: "support"
  resources:
    requests:
      memory: "4Gi"
      cpu: "1"
  service:
    type: LoadBalancer
    loadBalancerIP: ""
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"

  # Only overrides for chart/values.yaml defaults are listed here.
  sparkConf:
    "spark.dynamicAllocation.initialExecutors":                    "2"
    "spark.dynamicAllocation.minExecutors":                        "0"
    "spark.dynamicAllocation.maxExecutors":                        "10"
    "spark.kubernetes.executor.allocationBatchSize":               "10"
    "spark.kubernetes.executor.podNamePrefix":                     "thrift"     
    "spark.kubernetes.executor.node.selector.spark-executor":      "support"
# ── Spark History Server ─────────────────────────────────────────
historyServer:
  enabled: true
  nodeSelector:
    spark-history-server: "support"
  resources:
    requests:
      memory: "4Gi"
      cpu: "1"

  uiPort: 18080
  daemonMemory: "3g"

  service:
    type: LoadBalancer
    loadBalancerIP: ""
    port: 80
    annotations: {}
client:
  sparkConf:
    "spark.driver.memory":                                         "4g"
    "spark.driver.maxResultSize":                                  "4G"
    "spark.executor.memory":                                       "4g"
    "spark.executor.memoryOverhead":                               "4096m"
    "spark.kubernetes.driver.node.selector.spark-driver":          "support"
    "spark.kubernetes.executor.node.selector.spark-executor":      "support"
    "spark.sql.warehouse.dir":                                     "abfs://<container_name>@<account_name>.dfs.core.windows.net/hive/warehouse"
    # "spark.kubernetes.driver.label.app":                           "spark-pi"
    # "spark.kubernetes.executor.label.app":                         "spark-executor"
```
### 部署spark 
```
helm upgrade --install spark \
 oci://ghcr.io/wgqcd88/cahrts/spark \
 --version 3.5.4-20260423 \
 -f spark-values.yaml
```