# v2rayN 客户端路由建议

> 本文只记录可复用做法，不保存节点分享链接、UUID、Reality public key、short id 或完整客户端配置。

## 推荐日常模式

首选组合：

- 系统代理：自动配置系统代理
- 路由：V4-绕过大陆(Whitelist)
- TUN：需要接管命令行、Electron 应用、非浏览器客户端时开启
- DNS：使用 v2rayN 默认安全配置；TUN 下优先让客户端接管 DNS
- IPv6：先关闭；确认本机 IPv6 环境稳定后再打开

这个组合的含义是：国内域名和中国 IP 直连，Google/OpenAI/GitHub 等规则命中走代理，其余未命中的流量默认走代理出口。

## Xray 和 sing-box 怎么看

### 看当前实际核心

在 Windows PowerShell 里看进程：

```powershell
Get-Process v2rayN,xray,sing-box,mihomo -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,Path
```

如果看到 `xray`，当前节点流量主要由 Xray-core 处理。如果看到 `sing-box`，当前运行的是 sing-box。TUN 场景下 v2rayN 也可能生成 sing-box 配置来接管系统流量。

还可以看 v2rayN 生成的核心配置：

```powershell
Get-Content 'C:\Program Files\v2rayN\binConfigs\config.json' -Raw
```

注意不要把这份配置贴到公开位置，它包含完整节点凭据。

### 怎么切换

v2rayN 版本 UI 会变化，通常入口在：

- 节点列表右键当前节点，查看或编辑节点的 Core 类型
- 设置 / 参数设置 / Core 类型
- TUN 模式相关设置里选择 sing-box 或 sing-box TUN

保守建议：

- VLESS Reality TCP 443 普通系统代理：优先 Xray，兼容性最好。
- TUN：优先 sing-box，TUN/DNS/rule-set 体验通常更现代。
- 不确定时保持自动；先保证节点能连通，再优化 TUN。

## 规则最佳实践

不要把所有域名都手写死。最佳实践是：

1. 大面规则使用内置规则池：`geosite:cn`、`geoip:cn`、`geosite:google`、`geosite:private`、`geoip:private`。
2. 高价值服务使用显式兜底域名：OpenAI、Claude、GitHub、开发包仓库。
3. 定期更新 v2rayN 的 geo 数据文件，不自己维护完整地址池。

v2rayN 使用的 `geosite.dat` 规则来自社区维护的 domain-list 数据，规则写法类似 `geosite:google`、`geosite:cn`。上游说明见 [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community)，它说明每个 data 文件可以作为 `geosite:filename` 使用。加强版规则文件可以参考 [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)，但替换 geo 文件前要先备份。

推荐的活动规则顺序：

```text
1. 阻断 UDP 443
2. AI / Google / GitHub / 开发包仓库 -> proxy
3. 局域网 / private -> direct
4. 中国公共 DNS -> direct
5. geoip:cn -> direct
6. geosite:cn -> direct
7. 未命中 -> 默认 proxy
```

为什么要有第 2 条显式规则：AI 平台的域名变化快，`geosite` 不一定当天覆盖；显式列出核心域名可以减少“网页能开但登录/API/CDN 某一步失败”的概率。

## 仓库脚本

查看将要修改什么，不改文件：

```powershell
.\scripts\Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting
```

关闭 v2rayN 后应用推荐配置。如果 v2rayN 安装在 `C:\Program Files\v2rayN`，请用管理员 PowerShell 运行；普通权限下脚本会跳过只读配置目录：

```powershell
.\scripts\Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting
```

脚本会：

- 自动发现 `C:\Program Files\v2rayN` 和 `%LOCALAPPDATA%\v2rayN`。
- 备份 `guiNDB.db` 和 `guiNConfig.json`。
- 如果传入 `-ProfileAddress`，把匹配节点的 Reality SNI 修正为 `www.cloudflare.com`。
- 在当前活动路由前部插入 OpenAI / Claude / Google / GitHub / npm / PyPI 强制代理规则。
- 启用基础 TUN 开关：`EnableTun=true`、`AutoRoute=true`、`StrictRoute=true`、`EnableIPv6Address=false`。

如果节点 IP 变化，可以传参：

```powershell
.\scripts\actions\Set-V2rayNRecommendedRouting.ps1 -ProfileAddress '<server-ip>' -RealityServerName 'www.cloudflare.com' -Apply
```

应用后重启 v2rayN，并在界面确认：

- 当前节点仍是 `aws-tokyo-clean-reality`。
- 路由为 `V4-绕过大陆(Whitelist)`。
- 系统代理为自动配置。
- TUN 已开启；如果提示管理员重启，允许。

## 新机器配置流程

1. 安装 v2rayN。
2. 导入 `output/vless-reality-url.txt` 的节点链接。
3. 测试节点延迟和浏览器访问。
4. 运行 `Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting` 前先关闭 v2rayN；需要 dry-run 时直接调用 `scripts/actions/Set-V2rayNRecommendedRouting.ps1`。
5. 关闭 v2rayN，运行 `Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting`。
6. 以管理员身份启动 v2rayN，打开 TUN。
7. 测试 `https://chatgpt.com`、`https://github.com`、国内网站和命令行包管理器。

## 开机自动进入 TUN

可以开启，但需要管理员权限。建议：

- 使用 v2rayN 自带开机启动，不手动把快捷方式丢进启动目录。
- 保持 TUN 已开启后退出 v2rayN，让它保存状态。
- 下次登录如果提示管理员权限，允许。
- 如果没有自动进入 TUN，检查 Windows 安全软件、UAC、v2rayN 是否以管理员身份启动。

TUN 是系统级网络接管，遇到公司 VPN、网银、游戏反作弊、Docker/WSL 网络异常时，先临时关闭 TUN，只保留系统代理排查。
