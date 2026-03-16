### 创建镜像
```shell
sudo docker build -t azure/spark:3.5.7-1 .
```
### 创建 service account
```shell
kubectl apply -f spark-service-account.yaml
```
### 部署 spark history server
##### 修改 event log 存储地址，对象存储认证方式
```shell
kubectl apply -f spark-history.yaml
```
### 部署 spark thrift server
```shell
kubectl apply -f spark-thrift-server.yaml
```