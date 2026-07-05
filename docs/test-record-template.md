# 测试记录模板

> 测试结果可以截图或记录摘要，但不要保存包含节点链接、token、cookie、私钥、订阅链接的截图。

## 测试批次

| 项目 | 内容 |
| --- | --- |
| 测试日期 | YYYY-MM-DD |
| 测试地点/网络 | 家宽 / 公司 / 手机热点 |
| 客户端 | v2rayN / Hiddify / Clash Verge Rev |
| 客户端版本 |  |
| 服务端区域 | Tokyo / Singapore |
| Static IP | `<redacted>` |

## 基础连通性

| 测试项 | 期望结果 | 实际结果 | 备注 |
| --- | --- | --- | --- |
| 服务端 SSH | 可连接 | 未测 |  |
| 443 端口 | 可连接 | 未测 |  |
| 客户端 TUN | 正常启用 | 未测 |  |
| DNS 解析 | 无明显污染 | 未测 |  |
| 出口 IP | 显示 Lightsail 节点 IP | 未测 |  |
| v2rayN Xray 核心直测 | `Manage-LightsailProxy.ps1 -Action TestV2rayNCore` 成功 | 未测 |  |
| Reality 握手 | 服务端无 handshake failed | 未测 |  |

## 常用站点测试

| 站点/服务 | 域名示例 | 结果 | 备注 |
| --- | --- | --- | --- |
| ChatGPT | chatgpt.com | 未测 |  |
| OpenAI API | api.openai.com | 未测 |  |
| Codex | 相关 OpenAI 域名 | 未测 |  |
| GitHub Web | github.com | 未测 |  |
| GitHub clone/pull | github.com | 未测 |  |
| Google Search | google.com | 未测 |  |
| npm | registry.npmjs.org | 未测 |  |
| PyPI | pypi.org | 未测 |  |

## 命令测试摘要

只保存脱敏输出。

```powershell
# Windows PowerShell examples
curl https://api.ipify.org
curl https://chatgpt.com
git ls-remote https://github.com/git/git.git HEAD
npm ping
python -m pip index versions requests
```

## 问题记录

| 时间 | 现象 | 初步判断 | 处理 | 结果 |
| --- | --- | --- | --- | --- |
| YYYY-MM-DD HH:mm |  |  |  |  |

