### 制作镜像
```shell
sudo docker build -t azure/hivemetastore:3.1.3-1 .
```
### 初始化元数据
```shell
kubectl run hivemetastore --rm --tty -i --restart='Never' \
	--image  azure/hivemetastore:3.1.3-1 \
	--namespace default \
	--overrides='{"spec":{"nodeSelector":{"spark-driver-amd64":"support"}}}'  \
	--command /opt/hive/bin/schematool --  \
	-initSchema -dbType postgres --verbose -driver org.postgresql.Driver \
	-url "jdbc:postgresql://hivemetastore.postgres.database.azure.com:5432/hive?sslmode=require" \
	-passWord password@123 -userName hive
```
### 修改 hive-metastore.yaml 数据库连接地址,对象存储认证信息,镜像名称,标签
### 部署hive metastore 
```shell
kubectl apply -f hive-metastore.yaml
```