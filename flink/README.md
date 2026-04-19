### 创建cert-manager-values.yaml
```
global:
  nodeSelector:
    cert-manager: support
replicaCount: 2
extraArgs:
  - --concurrent-workers=20
  - --kube-api-qps=80
  - --kube-api-burst=160
webhook:
  replicaCount: 2
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1
    memory: 1Gi
```
### 安装cert-manager
```
helm upgrade --install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  -f cert-manager-values.yaml \
  --set crds.enabled=true
```
### 创建 flink-operator-values.yaml
```
defaultConfiguration:
  kubernetes.operator.reconcile.interval: 15 s
  kubernetes.operator.reconcile.parallelism: 16
  kubernetes.operator.kubernetes.client.qps: 50
  kubernetes.operator.kubernetes.client.burst: 100
  kubernetes.operator.job.upgrade.last-state.fallback.enabled: true
  kubernetes.operator.observer.checkpoint.trigger-grace-period: 120s
watchNamespaces:
  - flink
operatorPod:
  nodeSelector:
    flink-operator: support
  jvmArgs: "-Xms1g -Xmx1g -XX:+UseG1GC"
```
### 安装 flink-operator
```
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.14.0/
helm install flink-operator \
    flink-operator-repo/flink-kubernetes-operator \
    -n flink --create-namespace \
    -f flink-operator-values.yaml  \
    --version 1.14.0
```
### 导入flink 镜像到acr
```
az acr import -n <acr_name> \
	--source ghcr.io/wgqcd88/flink:2.2.0-plugin-2026041511 \
	--image azure/flink:2.2.0-plugin-2026041511
```
### 部署 flink 流任务
```
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  namespace: flink
  name: flink-app
spec:
  image: wgqacrjw.azurecr.io/azure/flink:2.2.0-20260329
  flinkVersion: v2_2
  flinkConfiguration:
    high-availability.type: kubernetes
    high-availability.storageDir: abfs://<container_name>@<storage_account_name>.dfs.core.windows.net/ha
    kubernetes.rest-service.exposed.type: LoadBalancer
    execution.checkpointing.interval: 60s
    execution.checkpointing.min-pause: 30s
    execution.checkpointing.timeout: 10min
    execution.checkpointing.externalized-checkpoint-retention: RETAIN_ON_CANCELLATION
    state.checkpoints.dir: abfs://<container_name>@<storage_account_name>.dfs.core.windows.net/checkpoints
    state.savepoints.dir: abfs://<container_name>@<storage_account_name>.dfs.core.windows.net/savepoints

    jobmanager.scheduler: Adaptive
    # 流模式可以不用history server
    jobmanager.archive.fs.dir: abfs://<container_name>@<storage_account_name>.dfs.core.windows.net/flink-archive

    kubernetes.operator.job.autoscaler.memory.tuning.enabled: "false"
    rest.flamegraph.enabled: "true"
    kubernetes.operator.job.autoscaler.scaling.enabled: "true"
    kubernetes.operator.job.autoscaler.metrics.window: 3m
    taskmanager.numberOfTaskSlots: "4"
    kubernetes.operator.job.autoscaler.enabled: "true"
    kubernetes.operator.job.autoscaler.stabilization.interval: 3m
    kubernetes.operator.job.autoscaler.target.utilization: "0.5"
    kubernetes.operator.job.autoscaler.target.utilization.boundary: "0.2"
    kubernetes.operator.job.autoscaler.restart.time: 2m
    kubernetes.operator.job.autoscaler.catch-up.duration: 10m
    pipeline.max-parallelism: "64"
    parallelism.default: "4"
    kubernetes.operator.job.autoscaler.scale-up.grace-period: 1m
    pipeline.metrics.latency.interval: 10000
    # kubernetes.operator.job.autoscaler.resource.aware.enabled: "false"
    fs.azure.data.blocks.buffer: bytebuffer
    fs.azure.account.oauth2.msi.endpoint: http://169.254.169.254/metadata/identity/oauth2/token
    fs.azure.account.oauth2.msi.tenant: <tenant_id>
    fs.azure.account.oauth2.client.id: <mi_client_id>
    fs.azure.account.auth.type: Custom
    fs.azure.account.oauth.provider.type: com.github.azure.hadoop.custom.auth.MSIFileCachedAccessTokenProvider
    fs.azure.account.hns.enabled: true
    fs.azure.custom.token.fetch.retry.count: 10
    fs.azure.custom.token.file.cache.path: /tmp/.azure
    execution.shutdown-on-application-finish: "true"

  serviceAccount: flink
  podTemplate:
    spec: 
      volumes:
        - name: host-cache
          hostPath:
            path: /tmp
            type: DirectoryOrCreate
      containers:
        - name: flink-main-container
          volumeMounts:
            - name: host-cache
              mountPath: /tmp/.azure
  jobManager:
    resource:
      memory: "8Gi"
      cpu: 2
    podTemplate:
      metadata:
        labels:
          app: flink-app
          component: jobmanager
      spec:
        nodeSelector:
          flink-jobmanager: support
  taskManager:
    resource:
      memory: "8Gi"
      cpu: 2
    podTemplate:
      metadata:
        labels:
          app: flink-app
          component: taskmanager
      spec:
        nodeSelector:
          flink-taskmanager: support

  job:
    jarURI: abfs://<container_name>@<storage_account_name>.dfs.core.windows.net/flink-kafka-azure-blob-2.2.0.jar
    args:
      - "--job.name"
      - "flink-kafka-to-azure-blob"
  
    parallelism: 4
    upgradeMode:  last-state  #stateless | last-state | savepoint
    state: running
```