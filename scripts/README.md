# scripts

这里放本项目的本地操作脚本。普通使用只需要记住一个入口：

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

`Manage-LightsailProxy.ps1` 会显示交互菜单。日常只运行这一条命令并按提示选择即可，包括区域切换、创建、重建、删除、连通性测试、v2rayN 路由设置、v2rayN core 测试、key pair 准备、PEM 修复和节点直连路由。

只有自动化、排障或已明确知道目标动作时，才直接指定动作：

```powershell
.\scripts\Manage-LightsailProxy.ps1 -Action SwitchRegion
.\scripts\Manage-LightsailProxy.ps1 -Action Test
.\scripts\Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting
```

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `Manage-LightsailProxy.ps1` | 唯一推荐的日常 PowerShell 入口 |
| `actions/` | 具体动作脚本，由统一入口调用；高级调试时可直接运行 |
| `internal/` | 公共库、模板渲染、AWS/Lightsail helper；不要直接运行 |
| `bash/` | Linux/macOS/WSL 兼容入口；当前主维护路径仍是 PowerShell |

## 动作菜单

| Action | 作用 |
| --- | --- |
| `SwitchRegion` | 选择目标区域，删除当前实例并创建目标区域节点；东京默认排第一 |
| `Test` | 检查当前实例、TCP 22/443、服务端 Xray/Reality 配置 |
| `Create` | 使用当前 `.env.local` 创建节点 |
| `Rebuild` | 在当前区域删除并重建节点 |
| `Delete` | 删除当前 Lightsail 实例 |
| `AddBypassRoute` | 给当前节点 IP 添加本机直连路由，避免调试流量绕进其他代理/TUN |
| `RemoveBypassRoute` | 移除当前节点 IP 的本机直连路由 |
| `ApplyV2rayNRouting` | 关闭 v2rayN 后，写入推荐路由/TUN 设置 |
| `TestV2rayNCore` | 退出 v2rayN 后，用 v2rayN 自带 Xray core 做本地代理直测 |
| `GenerateSecrets` | 生成或补齐本地代理协议密钥 |
| `EnsureKeyPair` | 确保当前区域 Lightsail key pair 存在，并回写 `SSH_KEY_NAME` |
| `RepairPem` | 修复本地 PEM 私钥换行格式 |

## 本地配置文件

- `.env.local`：部署参数，例如 AWS 区域、实例名、Lightsail key pair 名称。
- `secrets.local.env`：代理协议凭据，例如 VLESS UUID、Reality key、Reality short id。

这两个文件都被 `.gitignore` 忽略。

## 区域切换

日常运行统一入口，然后选择 `Switch region / rebuild node`：

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

切换脚本会用方向键菜单选择目标区域，东京默认排在第一位。选择预设区域后会显示默认值，按 Enter 接受或输入新值覆盖。它会删除当前 `.env.local` 指向的实例，切换配置到目标区域，确保目标区域 Lightsail key pair 存在并回写 `SSH_KEY_NAME`，创建新节点，执行直连和服务端验证，生成客户端 URL，并在终端打印 v2rayN 可导入的 VLESS URL。

如果验证发现当前 IP 从本机直连不可用，脚本会询问是否删除该实例并在同一区域重建。

## v2rayN 路由

VLESS URL 不能嵌入 v2rayN 路由规则。区域切换会额外生成：

```text
output/v2rayn-routing-rules.json
output/v2rayn-routing-bundle.json
output/v2rayn-routing-notes.txt
```

关闭 v2rayN 后，运行统一入口并选择 `Apply recommended v2rayN routing`：

```powershell
.\scripts\Manage-LightsailProxy.ps1
```

## Bash 兼容入口

Bash 脚本移到了 `scripts/bash/`，保留给 Linux/macOS/WSL 复用：

```bash
./scripts/bash/generate-secrets.sh
./scripts/bash/create-lightsail.sh
./scripts/bash/rebuild-proxy.sh
./scripts/bash/delete-lightsail.sh --yes
```

## 安全边界

不要在脚本中保存或提交：

- AWS access key / secret key / session token
- SSH 私钥内容
- 完整 VLESS URI
- 客户端订阅链接
- 二维码或完整客户端导出配置

`output/` 下的渲染结果包含代理连接凭据，只能本地使用，不提交。
