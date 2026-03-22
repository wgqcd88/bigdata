
#### 创建jobmanager pod-template
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: flink
    component: jobmanager
spec:
  nodeSelector:
    flink-jobmanager: support  
```
#### 创建taskmanager pod-template
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: flink
    component: taskmanager
spec:
  nodeSelector:
    flink-taskmanager: support

```


#### 提交任务命名 session模式
```shell
bin/kubernetes-session.sh \
  -Dkubernetes.cluster-id=flink-session \
  -Dkubernetes.container.image.ref=wgqacr.azurecr.io/wgq/flink:2.2.0-20260318-2 \
  -Dkubernetes.namespace=flink \
  -Dkubernetes.jobmanager.service-account=flink \
  -Dkubernetes.taskmanager.service-account=flink \
  -Dkubernetes.rest-service.exposed.type=LoadBalancer \
  -Dkubernetes.rest-service.annotations.service.beta.kubernetes.io/azure-load-balancer-internal=true
```
```shell
bin/sql-client.sh embedded \
  -Dexecution.target=remote \
  -Drest.address=10.224.1.38  \
  -Drest.port=8081
```
```shell
CREATE TABLE print_sink (
  id INT,
  name STRING,
  score DOUBLE
) WITH (
  'connector' = 'print'
);

INSERT INTO print_sink VALUES
  (1, 'Alice', 95.5),
  (2, 'Bob', 88.0),
  (3, 'Charlie', 76.5);
```