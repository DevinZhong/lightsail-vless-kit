# scripts

这里放可复用、脱敏、可审计的脚本。

## 本地配置文件

- `.env.local`：部署参数，例如 AWS 区域、实例名、Lightsail key pair 名称。
- `secrets.local.env`：代理协议凭据，例如 VLESS UUID、Reality key、Hysteria2 password。

这两个文件都被 `.gitignore` 忽略。

## 主要入口

Windows / PowerShell 是当前主维护路径：

```powershell
.\scripts\Generate-Secrets.ps1
.\scripts\New-LightsailProxy.ps1
.\scripts\Rebuild-LightsailProxy.ps1
.\scripts\Remove-LightsailProxy.ps1
.\scripts\Test-NodeConnectivity.ps1
```

Bash 脚本保留给 Linux/macOS/WSL：

```bash
./scripts/generate-secrets.sh
./scripts/create-lightsail.sh
./scripts/rebuild-proxy.sh
./scripts/delete-lightsail.sh --yes
```

## 脚本分组

| 类型 | 脚本 | 说明 |
| --- | --- | --- |
| 部署入口 | `New-LightsailProxy.ps1`, `create-lightsail.sh` | 创建实例、开放端口、渲染客户端配置 |
| 重建/删除 | `Rebuild-LightsailProxy.ps1`, `Remove-LightsailProxy.ps1`, `rebuild-proxy.sh`, `delete-lightsail.sh` | 删除旧实例并重建，或只删除实例 |
| 渲染 | `Render-CloudInit.ps1`, `Render-ClientConfigs.ps1`, `render-cloud-init.sh`, `render-client-configs.sh` | 从模板生成本地输出 |
| 检查 | `Test-NodeConnectivity.ps1`, `Test-V2rayNCore.ps1`, `Wait-Ssh.ps1`, `wait-ssh.sh` | 排查云侧、端口、SSH、本地 v2rayN core |
| 客户端辅助 | `Set-V2rayNRecommendedRouting.ps1`, `Add-NodeBypassRoute.ps1`, `Remove-NodeBypassRoute.ps1` | 管理 v2rayN 推荐路由和本机临时直连路由 |
| 公共库 | `common.ps1`, `common.sh` | 公共函数，不直接运行 |

目前没有确认可以直接删除的临时调试脚本。测试和客户端辅助脚本虽然带排障属性，但属于可复用工具。

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
