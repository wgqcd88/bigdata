### AWS S3 to Aazure blob
#### 安装 azcopy
```yaml
curl -Lo /tmp/azcopy.tar https://aka.ms/downloadazcopy-v10-linux 
tar zxf /tmp/azcopy.tar -C /tmp/
mv /tmp/azcopy_linux_amd64*/azcopy /usr/bin/
rm -rf /tmp/azcopy.tar /tmp/azcopy_linux_amd64*
```

#### 配置S3 认证信息
``` shell
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>
export AWS_DEFAULT_REGION=<bucket-region>
```
#### azcopy 登录  
```shell
azcopy login
```
    1. 浏览器打开https://login.microsoft.com/device
    2. 输入控制台打印的code
    3. 登录azure账户
    4. 授权azcopy 登录
    5. 浏览器打开https://ms.portal.azure.com/对象存储授权当前登录用户 Storage Blob Data Owner 权限
#### 同步数据
```shell
azcopy copy \
  'https://<bucket-name>.s3-<region-name>.amazonaws.com/data' \
  'https://<service-account-name>.blob.core.windows.net/<container-name>/data/' \
  --recursive=true 
```

