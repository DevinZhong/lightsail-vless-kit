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
        "lightsail:ImportKeyPair",
        "lightsail:GetKeyPair",
        "lightsail:GetKeyPairs",
        "lightsail:DeleteKeyPair",
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

- `lightsail:ImportKeyPair` 用于上传本地 SSH 公钥到 Lightsail。
- `lightsail:GetKeyPairs` 用于确认 key pair 是否已存在。
- `lightsail:DeleteKeyPair` 是可选清理权限；不想给删除权限时可以移除。
- 不要使用 `LightsailExportAccess`，它不是创建实例所需的权限。
- 不建议使用 `AdministratorAccess`。

## AWS CLI Profile

本地配置：

```powershell
aws configure --profile personal-fixed-exit
```

验证：

```powershell
aws sts get-caller-identity --profile personal-fixed-exit
```

项目 `.env.local` 使用：

```bash
AWS_PROFILE=personal-fixed-exit
AWS_REGION=ap-northeast-1
AWS_AZ=ap-northeast-1a
```

## SSH Key Pair

建议使用项目专用 RSA key pair，不复用日常 SSH key：

```powershell
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\personal-fixed-exit-lightsail -C "personal-fixed-exit-lightsail"
```

导入 Lightsail：

```powershell
# Lightsail expects the base64 key body, not the whole authorized_keys line.
# The .pub file should look like: ssh-rsa AAAA... personal-fixed-exit-lightsail
$pubLine = (Get-Content "$env:USERPROFILE\.ssh\personal-fixed-exit-lightsail.pub" -Raw).Trim()
$parts = $pubLine -split '\s+'
if ($parts[0] -ne 'ssh-rsa') { throw "Lightsail import-key-pair expects ssh-rsa. Found: $($parts[0])" }
$pub = $parts[1]

aws lightsail import-key-pair `
  --profile personal-fixed-exit `
  --region ap-northeast-1 `
  --key-pair-name personal-fixed-exit-lightsail `
  --public-key-base64 $pub
```

确认：

```powershell
aws lightsail get-key-pairs `
  --profile personal-fixed-exit `
  --region ap-northeast-1
```

然后在 `.env.local` 中设置：

```bash
SSH_KEY_NAME=personal-fixed-exit-lightsail
```

