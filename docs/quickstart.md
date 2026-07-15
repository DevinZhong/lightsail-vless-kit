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
aws sts get-caller-identity --profile lightsail-vless-kit
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
AWS_PROFILE=lightsail-vless-kit
SSH_KEY_NAME=lightsail-vless-kit-lightsail
SSH_ALLOWED_CIDR=<your-public-ip>/32
```

`SSH_ALLOWED_CIDR=0.0.0.0/0` 最省事，但不适合作为长期设置。能固定本机公网 IP 时，优先改成 `/32`。

## 3. 首次启动并进行环境预检

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

首次启动会询问界面语言；系统为中文时默认建议“简体中文”。选择 `环境预检（推荐首次运行）`，确认 `.env.local`、AWS CLI 登录态和必要部署参数都通过。语言选择仅保存在 `.lightsail-vless-kit.user.json`，与部署配置和凭据分离，也不会提交到 Git。

## 4. 生成代理协议密钥

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

在菜单中选择 `Generate or repair local proxy secrets`。脚本会写入 `secrets.local.env`。如果本机没有 `xray.exe`，可以在可信环境运行 `xray uuid`、`xray x25519`、`openssl rand -hex 8` 后手动填写。

## 5. 创建 Lightsail 节点

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

在菜单中选择“按当前 `.env.local` 创建节点”。脚本会完成：

1. 确保当前区域的 Lightsail SSH key pair 与本机 PEM 都可用。
2. 渲染 `output/cloud-init.sh`。
3. 创建 Lightsail Ubuntu 实例。
4. 开放 SSH 和 TCP 443。
5. 等待公网 IP 和 SSH。
6. 渲染本地客户端导入文件。

生成的客户端文件在 `output/` 下，包含真实节点凭据，只能本机使用：

```text
output/vless-reality-url.txt
output/subscription.txt
```

## 6. 验证服务端

先在本机检查云侧和端口：

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

在菜单中选择 `Test current node connectivity`。

如果需要登录服务器：

```powershell
ssh -i $env:USERPROFILE\.ssh\lightsail-vless-kit-lightsail.pem ubuntu@<server-ip>
```

服务器上常用检查：

```bash
sudo systemctl status xray --no-pager
sudo journalctl -u xray -e
sudo tail -n 200 /var/log/proxy-bootstrap.log
sudo ss -lntup
```

## 7. 导入客户端

Windows 首选 v2rayN：

1. 导入 `output/vless-reality-url.txt`。
2. 先用系统代理测试浏览器访问。
3. 稳定后再启用 TUN 和规则路由。

客户端路由建议见 [v2rayn-routing.md](v2rayn-routing.md)。

关闭 v2rayN 后，可以应用推荐设置：

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

在菜单中选择 `Apply recommended v2rayN routing`。统一入口会维护推荐路由/TUN 设置；需要指定 `-ProfileAddress` 等高级参数时，才直接调用 `scripts/actions/Set-V2rayNRecommendedRouting.ps1`。

## 区域选择

“切换区域 / 重建节点”会从当前 AWS 账户动态读取 Lightsail 可用区域和 Availability Zone，不再假设某个固定 `a` 区一定可用。菜单将东京、首尔、新加坡作为面向中国大陆用户的优先尝试项；Oregon 和 Virginia 标为“美国 IP”选项。实际网络体验依赖本地运营商和目标服务，请以创建后的连通性检查为准。

选择“全部可用区域”可查看 AWS 当前返回的完整列表。区域迁移会先创建并验证新节点，验证通过后才删除旧节点；迁移期间会短暂同时保留两台实例，可能产生少量重叠费用。若只是同一区域重建，请使用“重建当前区域节点”。

## Bash 路径

非 Windows 环境也保留 Bash 脚本：

```bash
cp .env.example .env.local
cp secrets.example.env secrets.local.env
./scripts/bash/generate-secrets.sh
./scripts/bash/create-lightsail.sh
```

当前项目主维护路径是 PowerShell。Bash 路径目前只完成语法 CI 检查，尚未完成 Linux/macOS 实机验证；请将其视作实验性兼容入口。
