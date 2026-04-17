#!/bin/bash
set -euo pipefail

# ============================================================
# 新加坡 (southeastasia) 一键部署脚本
# Azure 基础设施 → MySQL → Storage PE → NSG → AKS 配置 →
# Hive Metastore Schema Init → Hive Metastore → Spark
# ============================================================

LOCATION="southeastasia"
PREFIX="wgq-sea"
TAGS="CostControl=Ignore SecurityControl=Ignore"

# ── 命名 ──────────────────────────────────────────────────────
RG="${PREFIX}"
MI_NAME="${PREFIX}-mi"
VNET_NAME="${PREFIX}-vnet"
SUBNET_NODE="${PREFIX}-subnet-node"
SUBNET_POD="${PREFIX}-subnet-pod"
SUBNET_MYSQL="${PREFIX}-subnet-mysql"
SUBNET_PE="${PREFIX}-subnet-pe"
DNS_ZONE="sea.wgqcd.com"
ACR_NAME="wgqsea"
AKS_NAME="${PREFIX}-aks"
STORAGE_NAME="wgqsea"
MYSQL_NAME="${PREFIX}-mysql"
K8S_VERSION="1.33"

# ── MySQL 配置 ────────────────────────────────────────────────
MYSQL_ADMIN_USER="azureuser"
MYSQL_ADMIN_PASSWORD="P@ssword123!"
MYSQL_SKU="Standard_D2ds_v4"
MYSQL_STORAGE_GB=64

# ── 镜像源 ACR (跨区域拉取) ────────────────────────────────────
SOURCE_ACR="wgqacrjw"
HIVE_IMAGE="${SOURCE_ACR}.azurecr.io/wgq/hive-metastore:3.1.3-20260407"
SPARK_IMAGE="${SOURCE_ACR}.azurecr.io/wgq/spark:3.5.4-20260414"

# ── 网络 CIDR ─────────────────────────────────────────────────
VNET_CIDR="10.100.0.0/16"
SUBNET_NODE_CIDR="10.100.0.0/20"
SUBNET_POD_CIDR="10.100.64.0/18"
SUBNET_MYSQL_CIDR="10.100.48.0/24"
SUBNET_PE_CIDR="10.100.49.0/24"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEP=0
TOTAL=14

log() { echo ""; echo "[$((++STEP))/$TOTAL] $1"; echo "────────────────────────────────────────"; }

# ═══════════════════════════════════════════════════════════════
# PHASE 1: Azure 基础设施
# ═══════════════════════════════════════════════════════════════

log "创建 Resource Group"
az group create --name "$RG" --location "$LOCATION" --tags $TAGS -o none

log "创建 Managed Identity"
az identity create --name "$MI_NAME" --resource-group "$RG" --location "$LOCATION" --tags $TAGS -o none

MI_ID=$(az identity show --name "$MI_NAME" --resource-group "$RG" --query id -o tsv)
MI_PRINCIPAL_ID=$(az identity show --name "$MI_NAME" --resource-group "$RG" --query principalId -o tsv)
MI_CLIENT_ID=$(az identity show --name "$MI_NAME" --resource-group "$RG" --query clientId -o tsv)
MI_TENANT_ID=$(az identity show --name "$MI_NAME" --resource-group "$RG" --query tenantId -o tsv)
echo "  MI Client ID:    $MI_CLIENT_ID"
echo "  MI Principal ID: $MI_PRINCIPAL_ID"
echo "  MI Tenant ID:    $MI_TENANT_ID"

log "创建 VNet + 子网 (Node / Pod / MySQL / PE)"
az network vnet create \
  --name "$VNET_NAME" --resource-group "$RG" --location "$LOCATION" \
  --address-prefix "$VNET_CIDR" \
  --subnet-name "$SUBNET_NODE" --subnet-prefix "$SUBNET_NODE_CIDR" \
  --tags $TAGS -o none

az network vnet subnet create \
  --name "$SUBNET_POD" --resource-group "$RG" --vnet-name "$VNET_NAME" \
  --address-prefix "$SUBNET_POD_CIDR" -o none

az network vnet subnet create \
  --name "$SUBNET_MYSQL" --resource-group "$RG" --vnet-name "$VNET_NAME" \
  --address-prefix "$SUBNET_MYSQL_CIDR" \
  --delegations Microsoft.DBforMySQL/flexibleServers -o none

az network vnet subnet create \
  --name "$SUBNET_PE" --resource-group "$RG" --vnet-name "$VNET_NAME" \
  --address-prefix "$SUBNET_PE_CIDR" -o none

NODE_SUBNET_ID=$(az network vnet subnet show --name "$SUBNET_NODE" -g "$RG" --vnet-name "$VNET_NAME" --query id -o tsv)
POD_SUBNET_ID=$(az network vnet subnet show --name "$SUBNET_POD" -g "$RG" --vnet-name "$VNET_NAME" --query id -o tsv)
MYSQL_SUBNET_ID=$(az network vnet subnet show --name "$SUBNET_MYSQL" -g "$RG" --vnet-name "$VNET_NAME" --query id -o tsv)
PE_SUBNET_ID=$(az network vnet subnet show --name "$SUBNET_PE" -g "$RG" --vnet-name "$VNET_NAME" --query id -o tsv)
VNET_ID=$(az network vnet show --name "$VNET_NAME" -g "$RG" --query id -o tsv)

log "创建 Public DNS Zone / ACR / Storage Account (HNS)"
az network dns zone create --name "$DNS_ZONE" --resource-group "$RG" --tags $TAGS -o none &
az acr create --name "$ACR_NAME" --resource-group "$RG" --location "$LOCATION" --sku Basic --tags $TAGS -o none &
az storage account create \
  --name "$STORAGE_NAME" --resource-group "$RG" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --hns true --tags $TAGS -o none &
wait
echo "  DNS Zone / ACR / Storage 创建完成"

log "创建 AKS 集群 (~5 min)"
az aks create \
  --name "$AKS_NAME" --resource-group "$RG" --location "$LOCATION" \
  --kubernetes-version "$K8S_VERSION" \
  --node-count 1 --node-vm-size Standard_D8ds_v5 --nodepool-name system \
  --network-plugin azure \
  --vnet-subnet-id "$NODE_SUBNET_ID" --pod-subnet-id "$POD_SUBNET_ID" \
  --enable-managed-identity \
  --assign-identity "$MI_ID" --assign-kubelet-identity "$MI_ID" \
  --attach-acr "$ACR_NAME" \
  --generate-ssh-keys --tags $TAGS -o none

log "创建 MySQL Flexible Server (~5 min)"
az mysql flexible-server create \
  --name "$MYSQL_NAME" --resource-group "$RG" --location "$LOCATION" \
  --tier GeneralPurpose --sku-name "$MYSQL_SKU" --storage-size "$MYSQL_STORAGE_GB" \
  --admin-user "$MYSQL_ADMIN_USER" --admin-password "$MYSQL_ADMIN_PASSWORD" \
  --version 8.0.21 \
  --vnet "$VNET_NAME" --subnet "$SUBNET_MYSQL" \
  --private-dns-zone "${MYSQL_NAME}.private.mysql.database.azure.com" \
  --yes --tags $TAGS -o none

# ═══════════════════════════════════════════════════════════════
# PHASE 2: 网络与权限
# ═══════════════════════════════════════════════════════════════

log "创建 Storage Private Endpoints + Private DNS Zones"
STORAGE_ID=$(az storage account show --name "$STORAGE_NAME" -g "$RG" --query id -o tsv)

# Blob PE
az network private-endpoint create \
  --name "${STORAGE_NAME}-pe-blob" --resource-group "$RG" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$SUBNET_PE" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id blob --connection-name "${STORAGE_NAME}-blob-conn" -o none

# DFS PE
az network private-endpoint create \
  --name "${STORAGE_NAME}-pe-dfs" --resource-group "$RG" --location "$LOCATION" \
  --vnet-name "$VNET_NAME" --subnet "$SUBNET_PE" \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id dfs --connection-name "${STORAGE_NAME}-dfs-conn" -o none

# Private DNS Zones + VNet Link + Zone Groups
for SVC in blob dfs; do
  ZONE="privatelink.${SVC}.core.windows.net"
  az network private-dns zone create --resource-group "$RG" --name "$ZONE" -o none
  az network private-dns link vnet create \
    --resource-group "$RG" --zone-name "$ZONE" \
    --name "${PREFIX}-${SVC}-link" --virtual-network "$VNET_ID" \
    --registration-enabled false -o none
  az network private-endpoint dns-zone-group create \
    --resource-group "$RG" --endpoint-name "${STORAGE_NAME}-pe-${SVC}" \
    --name "${SVC}-zone-group" --private-dns-zone "$ZONE" \
    --zone-name "${SVC}" -o none
done
echo "  Blob PE + DFS PE + Private DNS 创建完成"

log "MI 角色赋权"
RG_ID=$(az group show --name "$RG" --query id -o tsv)
ACR_ID=$(az acr show --name "$ACR_NAME" -g "$RG" --query id -o tsv)
DNS_ZONE_ID=$(az network dns zone show --name "$DNS_ZONE" -g "$RG" --query id -o tsv)

# 等待 AKS MC_ 资源组创建完成
MC_RG="MC_${RG}_${AKS_NAME}_${LOCATION}"
MC_RG_ID=$(az group show --name "$MC_RG" --query id -o tsv 2>/dev/null || echo "")

assign_role() {
  local ROLE="$1" SCOPE="$2"
  az role assignment create \
    --assignee-object-id "$MI_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
    --role "$ROLE" --scope "$SCOPE" -o none 2>/dev/null || true
  echo "  ✓ $ROLE"
}

assign_role "Contributor"                   "$RG_ID"
[ -n "$MC_RG_ID" ] && assign_role "Contributor" "$MC_RG_ID"
assign_role "Storage Blob Data Contributor" "$STORAGE_ID"
assign_role "Storage Blob Data Owner"       "$STORAGE_ID"
assign_role "AcrPull"                       "$ACR_ID"
assign_role "Network Contributor"           "$VNET_ID"
assign_role "Network Contributor"           "$NODE_SUBNET_ID"
assign_role "DNS Zone Contributor"          "$DNS_ZONE_ID"
assign_role "Managed Identity Operator"     "$MI_ID"

# 如果有跨区域 ACR 镜像源，赋权 AcrPull
if [ "$SOURCE_ACR" != "$ACR_NAME" ]; then
  SOURCE_ACR_ID=$(az acr show --name "$SOURCE_ACR" --query id -o tsv 2>/dev/null || echo "")
  if [ -n "$SOURCE_ACR_ID" ]; then
    assign_role "AcrPull" "$SOURCE_ACR_ID"
  fi
fi

log "配置 NSG 规则 (允许外部访问 80/443/8090/9001 和 NodePort)"
for NSG_NAME in $(az network nsg list -g "$RG" --query '[].name' -o tsv 2>/dev/null); do
  # AllowHTTP: 80,443,8090,9001
  az network nsg rule create --nsg-name "$NSG_NAME" -g "$RG" \
    --name AllowHTTPInbound --priority 100 --direction Inbound --access Allow \
    --protocol Tcp --source-address-prefixes Internet \
    --destination-port-ranges 80 443 8090 9001 -o none 2>/dev/null || true

  # AllowNodePort (仅 Node 子网 NSG, 允许 LB 健康探测 + Internet 流量)
  if [[ "$NSG_NAME" == *"subnet-node"* ]]; then
    az network nsg rule create --nsg-name "$NSG_NAME" -g "$RG" \
      --name AllowNodePorts --priority 110 --direction Inbound --access Allow \
      --protocol Tcp --source-address-prefixes '*' \
      --destination-port-ranges 30000-32767 -o none 2>/dev/null || true
  fi
  echo "  ✓ $NSG_NAME"
done

# ═══════════════════════════════════════════════════════════════
# PHASE 3: K8s 初始化 + 应用部署
# ═══════════════════════════════════════════════════════════════

log "获取 AKS 凭据 & 准备集群"
az aks get-credentials -g "$RG" -n "$AKS_NAME" --overwrite-existing

# 获取唯一 Node 名称
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "  Node: $NODE_NAME"

# 添加节点标签
kubectl label node "$NODE_NAME" \
  hive=support \
  spark-thrift-server=support \
  spark-history=support \
  spark-executor=support \
  code-server=support \
  --overwrite

# 创建命名空间
kubectl create namespace hive   --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace spark  --dry-run=client -o yaml | kubectl apply -f -

# 创建 Storage 容器 (history, spark)
echo "  创建 Storage 容器..."
STORAGE_KEY=$(az storage account keys list -g "$RG" -n "$STORAGE_NAME" --query '[0].value' -o tsv)
az storage container create --name history --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" -o none 2>/dev/null || true
az storage container create --name spark   --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" -o none 2>/dev/null || true
echo "  ✓ Storage 容器 (history, spark)"

echo "  ✓ 命名空间 / ConfigMap 就绪"

log "创建 MySQL 数据库 + Hive Schema 初始化"
# 创建 hive_metastore 数据库
az mysql flexible-server db create \
  --resource-group "$RG" --server-name "$MYSQL_NAME" \
  --database-name hive_metastore -o none 2>/dev/null || true

# 先部署 Hive (replicas=0, 仅创建 ConfigMap) 供 schema init Job 使用
echo "  部署 Hive Metastore ConfigMap (replicas=0)..."
helm upgrade --install hive-metastore "${SCRIPT_DIR}/hive/3.1.3/chart" \
  -n hive \
  -f "${SCRIPT_DIR}/hive/3.1.3/values-sea.yaml" \
  --set replicaCount=0 \
  --wait --timeout 60s 2>/dev/null || true

# 使用 K8s Job 初始化 Hive schema
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: hive-schema-init
  namespace: hive
spec:
  ttlSecondsAfterFinished: 600
  template:
    spec:
      nodeSelector:
        hive: "support"
      restartPolicy: Never
      containers:
      - name: schema-init
        image: ${HIVE_IMAGE}
        command: ["/opt/hive/bin/schematool"]
        args: ["-dbType", "mysql", "-initSchema", "--verbose"]
        volumeMounts:
        - name: hive-config
          mountPath: /opt/hive/conf/hive-site.xml
          subPath: hive-site.xml
      volumes:
      - name: hive-config
        configMap:
          name: hive-metastore-config
EOF

# 等待 schema init Job 完成
echo "  等待 Hive Schema 初始化..."
kubectl wait --for=condition=complete job/hive-schema-init -n hive --timeout=300s 2>/dev/null || {
  echo "  ⚠ Schema init Job 未完成，检查日志:"
  kubectl logs job/hive-schema-init -n hive --tail=10 2>/dev/null || true
}

log "部署 Hive Metastore"
helm upgrade --install hive-metastore "${SCRIPT_DIR}/hive/3.1.3/chart" \
  -n hive \
  -f "${SCRIPT_DIR}/hive/3.1.3/values-sea.yaml" \
  --wait --timeout 300s

echo "  等待 Hive Metastore Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=hive-metastore -n hive --timeout=180s
HIVE_SVC_IP=$(kubectl get svc hive-metastore -n hive -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
echo "  ✓ Hive Metastore Running (Service IP: $HIVE_SVC_IP)"

log "部署 Spark (Thrift Server + History Server)"

# 创建 Storage 目录 (eventlogs / decommission / warehouse)
echo "  创建 Storage 目录..."
az storage fs directory create -n spark/eventlogs -f history \
  --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" -o none 2>/dev/null || true
az storage fs directory create -n decommission -f spark \
  --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" -o none 2>/dev/null || true
az storage fs directory create -n hive/warehouse -f spark \
  --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" -o none 2>/dev/null || true
echo "  ✓ Storage 目录 (eventlogs, decommission, warehouse)"

helm upgrade --install spark "${SCRIPT_DIR}/spark/3.5.4/chart" \
  -n spark \
  -f "${SCRIPT_DIR}/spark/3.5.4/values-sea.yaml" \
  --wait --timeout 600s

echo "  等待 Spark Pods 就绪..."
kubectl wait --for=condition=ready pod -l app=spark-thrift-server -n spark --timeout=300s 2>/dev/null || {
  echo "  ⚠ Thrift Server 未 Ready，检查日志:"
  kubectl logs -l app=spark-thrift-server -n spark --tail=5 2>/dev/null || true
}
kubectl wait --for=condition=ready pod -l app=spark-history -n spark --timeout=180s 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# 部署完成 — 输出摘要
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              部署完成 — 资源摘要                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║ Region:          $LOCATION"
echo "║ Resource Group:  $RG"
echo "║ AKS:             $AKS_NAME (K8s $K8S_VERSION)"
echo "║ ACR:             $ACR_NAME.azurecr.io"
echo "║ Storage:         $STORAGE_NAME.dfs.core.windows.net (HNS)"
echo "║ MySQL:           $MYSQL_NAME.mysql.database.azure.com"
echo "║ DNS Zone:        $DNS_ZONE"
echo "║ MI Client ID:    $MI_CLIENT_ID"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║ VNet:  $VNET_NAME ($VNET_CIDR)"
echo "║   Node:   $SUBNET_NODE ($SUBNET_NODE_CIDR)"
echo "║   Pod:    $SUBNET_POD  ($SUBNET_POD_CIDR)"
echo "║   MySQL:  $SUBNET_MYSQL ($SUBNET_MYSQL_CIDR)"
echo "║   PE:     $SUBNET_PE    ($SUBNET_PE_CIDR)"
echo "╠════════════════════════════════════════════════════════════╣"

HIVE_IP=$(kubectl get svc hive-metastore -n hive -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")
THRIFT_IP=$(kubectl get svc spark-thrift-server -n spark -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")
HISTORY_IP=$(kubectl get svc spark-history -n spark -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")

echo "║ K8s Services:"
echo "║   Hive Metastore:       $HIVE_IP:9083"
echo "║   Spark Thrift Server:  $THRIFT_IP:10000"
echo "║   Spark History Server: http://$HISTORY_IP"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "连接 Spark Thrift Server:"
echo "  beeline -u 'jdbc:hive2://${THRIFT_IP}:10000'"
echo ""
echo "⚠ 记得在域名注册商添加 NS 委派: ${DNS_ZONE} → Azure DNS"
