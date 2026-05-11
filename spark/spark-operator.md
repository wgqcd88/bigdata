### 安装 nginx ingress
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.publishService.enabled=true \
  --set controller.nodeSelector.nginx=support
```
### 安装 spark-operator
```
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update
helm upgrade --install spark-operator spark-operator/spark-operator \
    --namespace spark-operator \
    --create-namespace \
	--set webhook.enable=true \
	--set batchScheduler.enable=true \
	--set controller.uiIngress.enable=true \
	--set controller.uiIngress.urlFormat='/{{$appNamespace}}/{{$appName}}' \
	--set controller.uiIngress.ingressClassName=nginx \
	--set controller.nodeSelector.spark-operator=support \
	--set webhook.nodeSelector.spark-operator=support 
```