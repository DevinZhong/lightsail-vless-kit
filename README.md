# personal-fixed-exit

低成本、低维护、可重复重建的个人固定外网出口环境项目。

目标是用本地脚本快速创建 AWS Lightsail 东京 Ubuntu 节点，通过 cloud-init 自动部署 Xray-core VLESS Reality TCP 443，并可选部署 Hysteria2 UDP 443 作为备用。Windows 客户端首选 v2rayN，重建后手动导入本地生成的节点 URL。

## 目标架构

- 云厂商：AWS Lightsail Global
- 默认区域：Tokyo / `ap-northeast-1`
- 默认可用区：`ap-northeast-1a`
- 默认系统：Ubuntu 24.04 LTS / `ubuntu_24_04`
- 默认套餐：Linux $5/月档 / `nano_3_0`
- 主协议：Xray-core VLESS Reality Vision TCP 443
- 备用协议：Hysteria2 UDP 443，可关闭
- Windows 客户端：v2rayN 首选，Hiddify 备用，Clash Verge Rev 用于复杂规则/TUN 场景
- 订阅策略：不维护远程固定订阅地址；每次重建生成本地 URL，手动导入客户端

## 绝对不要保存的内容

不要把以下任何内容写入 git、贴到 issue 或同步到不可信云盘：

- AWS access key、AWS secret key、AWS session token
- SSH 私钥、服务器登录密码
- VLESS UUID、Reality private key、short id
- Hysteria2 password
- 完整 VLESS/Hysteria2 分享链接、订阅文件、二维码
- `output/` 下的渲染结果
- `.env.local`、`secrets.local.env`

本项目的边界：

- AWS 凭证走本机 AWS CLI 登录态，不进入项目文件。
- SSH 私钥留在本机 `~/.ssh`、ssh-agent 或 AWS Lightsail key pair，不进入项目文件。
- 代理协议凭据放 `secrets.local.env`，该文件被 `.gitignore` 忽略。

## 目录结构

```text
.
├── README.md
├── .env.example
├── secrets.example.env
├── cloud-init/
│   └── cloud-init.tpl.sh
├── client-config/
│   ├── hysteria2-url.tpl
│   ├── hysteria2.yaml.tpl
│   ├── vless-reality-url.tpl
│   └── vless-reality.json.tpl
├── docs/
├── output/
│   └── .gitkeep
├── scripts/
│   ├── common.sh
│   ├── create-lightsail.sh
│   ├── delete-lightsail.sh
│   ├── generate-secrets.sh
│   ├── get-instance-ip.sh
│   ├── open-ports.sh
│   ├── rebuild-proxy.sh
│   ├── render-client-configs.sh
│   ├── render-cloud-init.sh
│   └── wait-ssh.sh
├── server-config/
│   ├── hysteria-config.tpl.yaml
│   ├── hysteria-server.service
│   ├── xray-config.tpl.json
│   └── xray.service
└── templates/
```

## AWS 设置

IAM 用户、权限策略和 SSH key pair 导入步骤见：docs/aws-setup.md。

## 前置条件

先由你完成：

1. 注册 AWS 账号。
2. 开启 AWS root 账号 MFA。
3. 配置预算提醒，例如 `$5`、`$10`。
4. 安装 AWS CLI v2。
5. 完成本机 AWS CLI 登录。
6. 准备 Lightsail key pair 或本机 SSH 公钥方案。

确认 AWS CLI：

```powershell
aws --version
aws sts get-caller-identity
```

查询 Lightsail 可用 blueprint / bundle：

```bash
aws lightsail get-blueprints --region ap-northeast-1
aws lightsail get-bundles --region ap-northeast-1
```

## 初始化本地配置

```bash
cp .env.example .env.local
cp secrets.example.env secrets.local.env
```

编辑 `.env.local`：

```bash
AWS_REGION=ap-northeast-1
AWS_AZ=ap-northeast-1a
LIGHTSAIL_INSTANCE_NAME=proxy-tokyo-01
LIGHTSAIL_BUNDLE_ID=nano_3_0
LIGHTSAIL_BLUEPRINT_ID=ubuntu_24_04
SSH_KEY_NAME=<your-lightsail-key-pair-name>
SSH_ALLOWED_CIDR=<your-public-ip>/32
```

生成代理协议凭据：

```bash
./scripts/generate-secrets.sh
```

注意：`generate-secrets.sh` 需要本地 `xray` 命令来生成 Reality x25519 key pair。没有本地 Xray 时，可以之后在可信机器上运行 `xray x25519` 并手动填入 `secrets.local.env`。

## 创建节点

```bash
./scripts/create-lightsail.sh
```

脚本会：

1. 渲染 `output/cloud-init.sh`。
2. 调用 AWS CLI 创建 Lightsail 实例。
3. 开放 TCP 443、UDP 443、SSH 22。
4. 等待公网 IP 和 SSH。
5. 生成本地客户端文件。

输出文件：

```text
output/vless-reality-url.txt
output/hysteria2-url.txt
output/subscription.txt
output/subscription.base64.txt
```

这些文件都包含代理连接凭据，已被 `.gitignore` 忽略。

## 重建节点

如果节点 IP 不可用，重建：

```bash
./scripts/rebuild-proxy.sh
```

默认 `REBUILD_DELETE_OLD=false`，如果同名实例还存在，创建会失败。确认要自动删旧实例时，在 `.env.local` 里设置：

```bash
REBUILD_DELETE_OLD=true
```

## 删除节点

```bash
./scripts/delete-lightsail.sh --yes
```

提醒：Lightsail `stop` 不等于完全停止计费；不用时应删除实例。Static IP 默认不启用，也默认不释放，避免误删。

## 服务器排查

SSH 登录后：

```bash
sudo systemctl status xray
sudo journalctl -u xray -e
sudo systemctl status hysteria-server
sudo journalctl -u hysteria-server -e
sudo tail -n 200 /var/log/proxy-bootstrap.log
sudo ss -lntup
```

## 设计取舍

- 不使用 3x-ui、v2ray-agent、Docker、Web 面板，减少维护面和攻击面。
- 默认不使用 Static IP，因为“IP 不行就快速重建”的模式更适合新 IP。
- 不维护远程固定订阅地址，重建频率低时手动导入本地 URL 更简单。
- Hysteria2 是备用协议，UDP 网络不稳定时可在 `.env.local` 设置 `HYSTERIA_ENABLED=false`。

