# personal-fixed-exit

低成本、低维护、可重复重建的个人固定外网出口环境项目。

目标是用本地脚本快速创建 AWS Lightsail Ubuntu 节点，通过 cloud-init 自动部署 Xray-core VLESS Reality TCP 443。Windows 客户端首选 v2rayN，重建后手动导入本地生成的节点 URL。

这是给有 AWS 与命令行基础的个人用户使用的脚本模板，不是机场面板、多用户服务或远程订阅服务。云资源费用、合规责任和对目标服务条款的遵守均由使用者自行承担；本项目不承诺匿名性、可用性，也不用于规避任何限制。

## 当前定位

- 云厂商：AWS Lightsail Global
- 默认区域：Tokyo / `ap-northeast-1`
- 默认系统：Ubuntu 24.04 LTS / `ubuntu_24_04`
- 默认套餐：Linux $5/月档 / `nano_3_0`
- 主协议：Xray-core VLESS Reality Vision TCP 443
- 默认 Xray 版本：固定在 `.env.example`；部署时校验上游同版本 SHA-256 摘要
- 客户端：Windows v2rayN 首选
- 订阅策略：不维护远程固定订阅地址；每次重建生成本地 URL，手动导入客户端

## 安全边界

绝对不要把以下内容提交到 git、贴到 issue 或同步到不可信云盘：

- AWS access key、AWS secret key、AWS session token
- SSH 私钥、服务器登录密码
- VLESS UUID、Reality private key、short id
- 完整 VLESS 分享链接、订阅文件、二维码
- `output/` 下的渲染结果
- `.env.local`、`secrets.local.env`

本项目的边界：

- AWS 凭证走本机 AWS CLI 登录态，不进入项目文件。
- SSH 私钥留在本机 `~/.ssh`、ssh-agent 或 AWS Lightsail key pair，不进入项目文件。
- 代理协议凭据放 `secrets.local.env`，该文件被 `.gitignore` 忽略。
- 渲染出的客户端文件放 `output/`，该目录内容被 `.gitignore` 忽略。

## 快速开始

初次部署按 [docs/quickstart.md](docs/quickstart.md) 走。

Windows PowerShell 主路径只需要一个统一入口：

```powershell
Copy-Item .env.example .env.local
Copy-Item secrets.example.env secrets.local.env
.\scripts\Manage-LightsailProxy.ps1
```

按菜单提示选择创建、检查、重建、换区或 v2rayN 路由设置即可；日常不需要记忆任何 `-Action` 参数。

如需自动化、排障或从其他脚本调用，才直接指定动作：

```powershell
.\scripts\Manage-LightsailProxy.ps1 -Action SwitchRegion
.\scripts\Manage-LightsailProxy.ps1 -Action Test
.\scripts\Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting
```

创建完成后，本地客户端 URL 会生成到：

```text
output/vless-reality-url.txt
output/subscription.txt
```

这些文件都包含代理连接凭据，只能本机使用。

## 重建和删除

节点不可用、IP 声誉异常或想换区域时，见 [docs/rebuild-and-delete.md](docs/rebuild-and-delete.md)。

从统一入口的菜单选择 `Rebuild current-region node`、`Delete current node` 或 `Switch region / rebuild node`：

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

重建或切换区域后 IP 和客户端 URL 会变化，需要重新导入 v2rayN。

## 文档索引

| 文档 | 用途 |
| --- | --- |
| [docs/quickstart.md](docs/quickstart.md) | 初次部署主流程 |
| [docs/rebuild-and-delete.md](docs/rebuild-and-delete.md) | 重建、删除、旧实例处理 |
| [docs/aws-setup.md](docs/aws-setup.md) | IAM、AWS CLI profile、Lightsail key pair |
| [docs/v2rayn-routing.md](docs/v2rayn-routing.md) | v2rayN 路由、TUN 和客户端辅助脚本 |
| [docs/maintenance.md](docs/maintenance.md) | 日常维护和排障顺序 |
| [docs/deployment-record.md](docs/deployment-record.md) | 脱敏部署记录模板 |
| [docs/client-config-template.md](docs/client-config-template.md) | 客户端配置记录模板 |
| [docs/test-record-template.md](docs/test-record-template.md) | 测试记录模板 |
| [docs/open-source-review.md](docs/open-source-review.md) | 开源复用价值和开源前检查 |
| [docs/releasing.md](docs/releasing.md) | 维护者发布清单 |

历史参考：

- [docs/server-runbook.md](docs/server-runbook.md)：人工部署手册，脚本化部署后不再作为主入口。
- [docs/rebuild-plan.md](docs/rebuild-plan.md)：早期重建规划，当前操作以 `rebuild-and-delete.md` 为准。

## 脚本索引

脚本说明见 [scripts/README.md](scripts/README.md)。

核心 PowerShell 入口：

```text
scripts/Manage-LightsailProxy.ps1
```

具体动作脚本位于 `scripts/actions/`，由统一入口调用；高级调试时才需要直接进入。

Bash 兼容入口保留给 Linux/macOS/WSL：

```text
scripts/bash/generate-secrets.sh
scripts/bash/create-lightsail.sh
scripts/bash/rebuild-proxy.sh
scripts/bash/delete-lightsail.sh
```

## 设计取舍

- 不使用 3x-ui、v2ray-agent、Docker、Web 面板，减少维护面和攻击面。
- 默认不使用 Static IP，因为“IP 不行就快速重建”的模式更适合新 IP。
- 不维护远程固定订阅地址，重建频率低时手动导入本地 URL 更简单。

## 许可证与安全

本项目以 [MIT License](LICENSE) 发布。安全问题请遵循 [SECURITY.md](SECURITY.md)，不要在公开 issue、截图或日志中提交任何连接凭据。

## 开源复用判断

这个项目有开源复用价值，适合定位为“个人固定出口节点的可审计脚本模板”。它不适合包装成大众一键面板，也不适合多用户售卖场景。

项目当前适合作为个人固定出口脚本模板开源；发布操作请按 [docs/releasing.md](docs/releasing.md) 执行。详细评估见 [docs/open-source-review.md](docs/open-source-review.md)。
