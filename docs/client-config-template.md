# 客户端配置模板

> 本文件用于记录 Windows 客户端配置思路和规则。不要保存节点分享链接、订阅链接、二维码、完整代理配置或任何明文密钥。

## Windows 客户端选择

| 客户端 | 用途 | 状态 |
| --- | --- | --- |
| v2rayN | 首选；适合 Xray-core / VLESS Reality / 固定节点 / 日常稳定使用 | 未配置 |
| Hiddify | 备用；适合开箱即用、多平台或移动端同步思路 | 未配置 |
| Clash Verge Rev | 复杂规则、复杂策略组、mihomo 工作流 | 未配置 |

## v2rayN 建议设置

第一阶段先追求可用和可验证：

- 核心：Xray
- 节点：手动添加 VLESS Reality
- 验证方式：先系统代理，再 TUN
- 路由模式：先全局或绕过大陆测试，再逐步切换规则模式
- 日志：排障时临时打开，确认后降低日志级别

不要导出完整配置到本仓库。

## 通用设置

- 模式：Rule / 规则模式
- TUN：稳定后启用
- DNS：优先使用客户端内置安全 DNS 或规则 DNS
- IPv6：按实际网络环境决定，异常时先关闭测试
- 开机启动：按需
- 系统代理：初期验证使用；TUN 正常后可不依赖系统代理

## 代理组建议

```yaml
proxy-groups:
  - name: Lightsail-VLESS
    type: select
    proxies:
      - <your-redacted-node-name>
      - DIRECT

  - name: Final
    type: select
    proxies:
      - DIRECT
      - Lightsail-VLESS
```

## 常用域名规则

以下只记录规则方向，不记录节点密钥。

```yaml
rules:
  # OpenAI / ChatGPT / Codex
  - DOMAIN-SUFFIX,openai.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,chatgpt.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,oaistatic.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,oaiusercontent.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,auth0.com,Lightsail-VLESS

  # GitHub
  - DOMAIN-SUFFIX,github.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,githubusercontent.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,githubassets.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,ghcr.io,Lightsail-VLESS

  # Google
  - DOMAIN-SUFFIX,google.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,gstatic.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,googleapis.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,googleusercontent.com,Lightsail-VLESS

  # Development
  - DOMAIN-SUFFIX,npmjs.org,Lightsail-VLESS
  - DOMAIN-SUFFIX,npmjs.com,Lightsail-VLESS
  - DOMAIN-SUFFIX,pypi.org,Lightsail-VLESS
  - DOMAIN-SUFFIX,pythonhosted.org,Lightsail-VLESS

  # Default
  - MATCH,Final
```

## v2rayN 记录

| 项目 | 内容 |
| --- | --- |
| 版本 |  |
| Core | Xray |
| 导入方式 | 手动 / 订阅 |
| 节点名称 | `<redacted>` |
| 系统代理 | 开 / 关 |
| TUN 状态 | 开 / 关 |
| 路由模式 | 全局 / 规则 / 绕过大陆 |
| 配置存放位置 | 密码管理器条目名称 |
| 备注 |  |

## Hiddify 记录

| 项目 | 内容 |
| --- | --- |
| 版本 |  |
| 导入方式 | 手动 / 订阅 |
| 节点名称 | `<redacted>` |
| TUN 状态 | 开 / 关 |
| 规则模式 | 开 / 关 |
| 备注 |  |

## Clash Verge Rev 记录

| 项目 | 内容 |
| --- | --- |
| 版本 |  |
| 配置来源 | 手动 / 订阅 |
| TUN 状态 | 开 / 关 |
| Service Mode | 已安装 / 未安装 |
| Mixed Port |  |
| 备注 |  |

## 重建后导入

重建节点后，脚本生成本地 URL 文件，再手动导入 v2rayN：

```text
output/vless-reality-url.txt
output/subscription.txt
```

不维护远程固定订阅地址。生成的 URL 和订阅文本包含完整节点凭据，不要提交到 git。
