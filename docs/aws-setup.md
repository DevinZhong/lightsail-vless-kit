# AWS 设置手册

> 不要把 AWS access key、secret key、SSH 私钥或代理密钥写入本仓库。

## IAM 用户

建议创建专用 IAM 用户：

```text
lightsail-cli
```

不要给这个用户开启 AWS 管理控制台登录，只用于本地 AWS CLI。

## 推荐 IAM Policy

创建自定义 policy，例如：

```text
PersonalFixedExitLightsailAccess
```

JSON：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LightsailRebuildAccess",
      "Effect": "Allow",
      "Action": [
        "lightsail:Get*",
        "lightsail:CreateInstances",
        "lightsail:DeleteInstance",
        "lightsail:OpenInstancePublicPorts",
        "lightsail:CloseInstancePublicPorts",
        "lightsail:CreateKeyPair",
        "lightsail:ImportKeyPair",
        "lightsail:GetKeyPair",
        "lightsail:GetKeyPairs",
        "lightsail:DeleteKeyPair",
        "lightsail:DownloadDefaultKeyPair",
        "lightsail:AllocateStaticIp",
        "lightsail:AttachStaticIp",
        "lightsail:DetachStaticIp",
        "lightsail:ReleaseStaticIp",
        "lightsail:GetStaticIp",
        "lightsail:GetStaticIps",
        "lightsail:GetInstance",
        "lightsail:GetInstances",
        "lightsail:GetBundles",
        "lightsail:GetBlueprints"
      ],
      "Resource": "*"
    }
  ]
}
```

说明：

- `lightsail:CreateKeyPair` 用于让 Lightsail 生成项目专用 SSH key pair。
- `lightsail:ImportKeyPair` 用于上传本地 SSH 公钥到 Lightsail；当前不作为首选路线。
- `lightsail:GetKeyPairs` 用于确认 key pair 是否已存在。
- `lightsail:DeleteKeyPair` 是可选清理权限；不想给删除权限时可以移除。
- 不要使用 `LightsailExportAccess`，它不是创建实例所需的权限。
- 不建议使用 `AdministratorAccess`。

## AWS CLI Profile

本地配置：

```powershell
aws configure --profile lightsail-vless-kit
```

验证：

```powershell
aws sts get-caller-identity --profile lightsail-vless-kit
```

项目 `.env.local` 使用：

```bash
AWS_PROFILE=lightsail-vless-kit
AWS_REGION=ap-northeast-1
AWS_AZ=ap-northeast-1a
```

## SSH Key Pair

首选：让 Lightsail 创建项目专用 key pair，并把私钥保存到本机用户 `.ssh` 目录。私钥不要放进项目目录。

```powershell
$keyBase64 = aws lightsail create-key-pair `
  --profile lightsail-vless-kit `
  --region ap-northeast-1 `
  --key-pair-name lightsail-vless-kit-lightsail `
  --query 'privateKeyBase64' `
  --output text

# AWS CLI returns a PEM private key text here, despite the field name privateKeyBase64.
# Save it as-is. Do not base64-decode it.
$keyPath = "$env:USERPROFILE\.ssh\lightsail-vless-kit-lightsail.pem"
Set-Content -Path $keyPath -Value $keyBase64 -NoNewline
```

确认：

```powershell
aws lightsail get-key-pairs `
  --profile lightsail-vless-kit `
  --region ap-northeast-1
```

然后在 `.env.local` 中设置：

```bash
SSH_KEY_NAME=lightsail-vless-kit-lightsail
```

之后 SSH 连接使用：

```powershell
ssh -i $env:USERPROFILE\.ssh\lightsail-vless-kit-lightsail.pem ubuntu@服务器IP
```

如果你已经创建过同名 key pair，`create-key-pair` 会失败。可以换一个 key pair 名称，或确认不用后删除旧 key pair。

## 备用：导入本地公钥

Lightsail `import-key-pair` 要求 `ssh-rsa` 类型，且 `--public-key-base64` 传入的是公钥行中间的 base64 key body。实际兼容性比 `create-key-pair` 更容易踩坑，因此只作为备用。

