# scripts

这里放可复用、脱敏、可审计的脚本。

## 本地配置文件

- `.env.local`：部署参数，例如 AWS 区域、实例名、Lightsail key pair 名称。
- `secrets.local.env`：代理协议凭据，例如 VLESS UUID、Reality key、Hysteria2 password。

这两个文件都被 `.gitignore` 忽略。

## 主要入口

```bash
./scripts/generate-secrets.sh
./scripts/create-lightsail.sh
./scripts/rebuild-proxy.sh
./scripts/delete-lightsail.sh --yes
```

Windows v2rayN 推荐路由和 TUN 设置：

```powershell
.\scripts\Set-V2rayNRecommendedRouting.ps1
.\scripts\Set-V2rayNRecommendedRouting.ps1 -Apply
```

## 安全边界

不要在脚本中保存：

- AWS access key / secret key / session token
- SSH 私钥内容
- 完整 VLESS URI
- 客户端订阅链接
- 二维码或完整客户端导出配置

`output/` 下的渲染结果包含代理连接凭据，只能本地使用，不提交。
