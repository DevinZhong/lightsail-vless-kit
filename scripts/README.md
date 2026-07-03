# scripts

这里放可复用、脱敏、可审计的脚本。

## 本地配置文件

- `.env.local`：部署参数，例如 AWS 区域、实例名、Lightsail key pair 名称。
- `secrets.local.env`：代理协议凭据，例如 VLESS UUID、Reality key、Hysteria2 password。

这两个文件都被 `.gitignore` 忽略。

## 用户直接运行

Windows / PowerShell 是当前主维护路径：

```powershell
.\scripts\Generate-Secrets.ps1
.\scripts\New-LightsailProxy.ps1
.\scripts\Test-NodeConnectivity.ps1
.\scripts\Rebuild-LightsailProxy.ps1
.\scripts\Remove-LightsailProxy.ps1
```

这些是主流程入口：

| 脚本 | 作用 |
| --- | --- |
| `Generate-Secrets.ps1` | 生成或补齐本地代理协议密钥 |
| `New-LightsailProxy.ps1` | 创建 Lightsail 实例并生成客户端导入文件 |
| `Test-NodeConnectivity.ps1` | 检查实例状态、IP、TCP 22/443 可达性 |
| `Rebuild-LightsailProxy.ps1` | 删除当前实例并用同一份本地配置重建 |
| `Remove-LightsailProxy.ps1` | 删除当前 Lightsail 实例 |

可选的本机/客户端辅助脚本：

| 脚本 | 作用 |
| --- | --- |
| `Set-V2rayNRecommendedRouting.ps1` | 修改 v2rayN 推荐路由和基础 TUN 设置 |
| `Test-V2rayNCore.ps1` | 退出 v2rayN 后，用 v2rayN 自带 Xray core 做本地直测 |
| `Add-NodeBypassRoute.ps1` | 给当前节点 IP 加直连路由，避免调试流量绕进其他代理/TUN |
| `Remove-NodeBypassRoute.ps1` | 移除上面的直连路由 |
| `Repair-LightsailPem.ps1` | 修复本地 Lightsail PEM 私钥换行格式 |

Bash 兼容入口保留给 Linux/macOS/WSL：

```bash
./scripts/generate-secrets.sh
./scripts/create-lightsail.sh
./scripts/rebuild-proxy.sh
./scripts/delete-lightsail.sh --yes
```

## 内部脚本

`scripts/internal/` 里的脚本由上面的入口调用，普通使用时不用手动运行：

| 类型 | 脚本 | 说明 |
| --- | --- | --- |
| 公共库 | `common.ps1`, `common.sh` | 读取本地配置、公共输出、模板替换、AWS CLI 包装 |
| 渲染 | `Render-CloudInit.ps1`, `Render-ClientConfigs.ps1`, `render-cloud-init.sh`, `render-client-configs.sh` | 从模板生成 cloud-init 和客户端文件 |
| 云侧 helper | `Open-Ports.ps1`, `Get-InstanceIp.ps1`, `open-ports.sh`, `get-instance-ip.sh` | 开放 Lightsail 端口、查询实例公网 IP |
| 等待/检查 helper | `Wait-Ssh.ps1`, `wait-ssh.sh` | 等待 SSH 端口可用 |

## v2rayN 推荐路由和 TUN 设置

```powershell
.\scripts\Set-V2rayNRecommendedRouting.ps1
.\scripts\Set-V2rayNRecommendedRouting.ps1 -ProfileAddress '<server-ip>' -Apply
```

不传 `-ProfileAddress` 时只维护路由/TUN，不更新任何节点 SNI。

## 安全边界

不要在脚本中保存：

- AWS access key / secret key / session token
- SSH 私钥内容
- 完整 VLESS URI
- 客户端订阅链接
- 二维码或完整客户端导出配置

`output/` 下的渲染结果包含代理连接凭据，只能本地使用，不提交。
