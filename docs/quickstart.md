# 初次部署指引

> 本文是新机器或首次使用本仓库时的主路径。不要把 AWS 凭证、SSH 私钥、代理密钥、订阅链接或完整节点 URI 写入仓库。

## 1. 准备 AWS 和本机工具

先完成这些一次性动作：

1. 注册 AWS 账号，并给 root 账号开启 MFA。
2. 设置预算提醒，例如 `$5` 和 `$10`。
3. 安装 AWS CLI v2。
4. 配置 AWS CLI profile，并确认身份可用。
5. 创建或准备 Lightsail key pair。

详细 IAM policy、AWS CLI profile 和 SSH key pair 做法见 [aws-setup.md](aws-setup.md)。

Windows 推荐用 PowerShell：

```powershell
aws --version
aws sts get-caller-identity --profile personal-fixed-exit
```

## 2. 初始化本地配置

复制示例文件：

```powershell
Copy-Item .env.example .env.local
Copy-Item secrets.example.env secrets.local.env
```

编辑 `.env.local`，至少确认这些值：

```text
AWS_REGION=ap-northeast-1
AWS_AZ=ap-northeast-1a
LIGHTSAIL_INSTANCE_NAME=proxy-tokyo-01
LIGHTSAIL_BUNDLE_ID=nano_3_0
LIGHTSAIL_BLUEPRINT_ID=ubuntu_24_04
AWS_PROFILE=personal-fixed-exit
SSH_KEY_NAME=personal-fixed-exit-lightsail
SSH_ALLOWED_CIDR=<your-public-ip>/32
```

`SSH_ALLOWED_CIDR=0.0.0.0/0` 最省事，但不适合作为长期设置。能固定本机公网 IP 时，优先改成 `/32`。

## 3. 生成代理协议密钥

```powershell
.\scripts\Generate-Secrets.ps1
```

脚本会写入 `secrets.local.env`。如果本机没有 `xray.exe`，可以在可信环境运行 `xray uuid`、`xray x25519`、`openssl rand -hex 8` 后手动填写。

## 4. 创建 Lightsail 节点

```powershell
.\scripts\New-LightsailProxy.ps1
```

脚本会完成：

1. 渲染 `output/cloud-init.sh`。
2. 创建 Lightsail Ubuntu 实例。
3. 开放 SSH、TCP 443，以及启用 Hysteria2 时的 UDP 443。
4. 等待公网 IP 和 SSH。
5. 渲染本地客户端导入文件。

生成的客户端文件在 `output/` 下，包含真实节点凭据，只能本机使用：

```text
output/vless-reality-url.txt
output/hysteria2-url.txt
output/subscription.txt
```

## 5. 验证服务端

先在本机检查云侧和端口：

```powershell
.\scripts\Test-NodeConnectivity.ps1
```

如果需要登录服务器：

```powershell
ssh -i $env:USERPROFILE\.ssh\personal-fixed-exit-lightsail.pem ubuntu@<server-ip>
```

服务器上常用检查：

```bash
sudo systemctl status xray --no-pager
sudo journalctl -u xray -e
sudo tail -n 200 /var/log/proxy-bootstrap.log
sudo ss -lntup
```

## 6. 导入客户端

Windows 首选 v2rayN：

1. 导入 `output/vless-reality-url.txt`。
2. 先用系统代理测试浏览器访问。
3. 稳定后再启用 TUN 和规则路由。

客户端路由建议见 [v2rayn-routing.md](v2rayn-routing.md)。

关闭 v2rayN 后，可以应用推荐设置：

```powershell
.\scripts\Set-V2rayNRecommendedRouting.ps1 -ProfileAddress '<server-ip>' -Apply
```

不传 `-ProfileAddress` 时，脚本只维护路由/TUN 设置，不会改节点 SNI。

## Bash 路径

非 Windows 环境也保留 Bash 脚本：

```bash
cp .env.example .env.local
cp secrets.example.env secrets.local.env
./scripts/generate-secrets.sh
./scripts/create-lightsail.sh
```

当前项目主维护路径是 PowerShell，Bash 脚本用于 Linux/macOS/WSL 复用。
