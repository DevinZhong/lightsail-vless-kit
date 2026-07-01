# 部署记录

> 本文件只记录脱敏信息。不要写入明文密钥、token、订阅链接、SSH 私钥或完整节点 URI。

## 基本信息

| 项目 | 内容 |
| --- | --- |
| 部署日期 | YYYY-MM-DD |
| 负责人 |  |
| 云厂商 | AWS Lightsail Global |
| 首选区域 | Tokyo |
| 实际区域 | Tokyo / Singapore |
| 实例规格 | Linux $5/月 |
| 操作系统 |  |
| 实例名称 |  |
| Static IP | `<redacted, e.g. x.x.x.123>` |
| 域名 | 无 / `<domain-redacted>` |

## 敏感信息存放位置

只写“在哪里”，不要写“是什么”。

| 类型 | 存放位置 |
| --- | --- |
| SSH 私钥 | 密码管理器 / 本机安全路径 |
| VLESS UUID | 密码管理器条目名称 |
| Reality private key | 密码管理器条目名称 |
| Reality public key | 可公开 / 仍建议脱敏记录 |
| short id | 密码管理器条目名称 |
| 客户端订阅链接 | 密码管理器条目名称 |

## Lightsail 操作记录

| 时间 | 操作 | 结果 | 备注 |
| --- | --- | --- | --- |
| YYYY-MM-DD HH:mm | 创建实例 | 成功 / 失败 |  |
| YYYY-MM-DD HH:mm | 绑定 Static IP | 成功 / 失败 |  |
| YYYY-MM-DD HH:mm | 配置防火墙 | 成功 / 失败 | 仅开放 SSH 和 443 |

## 服务端部署记录

| 项目 | 内容 |
| --- | --- |
| 服务端实现 | Xray / sing-box |
| 协议 | VLESS Reality |
| 传输 | TCP |
| 端口 | 443 |
| SNI / server name | `<redacted-or-public-domain>` |
| 指纹 | chrome / firefox / safari |
| systemd 服务名 |  |
| 配置文件路径 |  |

## 命令摘要

不要粘贴包含密钥的完整命令。可以记录脱敏命令或步骤摘要。

```bash
# 示例
sudo apt update && sudo apt upgrade
sudo systemctl status <service-name>
sudo journalctl -u <service-name> --no-pager -n 100
```

## 变更记录

| 日期 | 变更 | 原因 | 验证结果 |
| --- | --- | --- | --- |
| YYYY-MM-DD |  |  |  |

