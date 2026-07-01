# 维护手册

> 维护记录同样必须脱敏。不要保存明文密钥、token、订阅链接、SSH 私钥或完整节点 URI。

## 周期性检查

| 周期 | 检查项 | 说明 |
| --- | --- | --- |
| 每周 | 服务状态 | `systemctl status <service-name>` |
| 每周 | 日志异常 | `journalctl -u <service-name> --no-pager -n 100` |
| 每月 | Lightsail 账单 | 确认实例、Static IP、流量费用 |
| 每月 | 系统更新 | 安全更新优先 |
| 每月 | 客户端版本 | Hiddify / Clash Verge Rev 更新 |
| 变更后 | 全量测试 | 使用 `docs/test-record-template.md` |

## 常见维护命令

```bash
sudo systemctl status <service-name>
sudo systemctl restart <service-name>
sudo journalctl -u <service-name> --no-pager -n 100
sudo ss -lntp
```

## 故障排查顺序

1. 确认 Lightsail 实例运行中。
2. 确认 Static IP 仍绑定到目标实例。
3. 确认 Lightsail 防火墙允许 TCP 443。
4. 确认服务端进程正在监听 TCP 443。
5. 确认客户端节点参数没有被误改。
6. 确认 TUN / Service Mode / DNS 设置正常。
7. 分别测试直连、规则代理、全局代理，缩小问题范围。

## 轮换建议

- SSH 私钥：怀疑泄漏时立即轮换。
- VLESS UUID / Reality key：客户端设备丢失、配置泄漏、异常连接时轮换。
- Static IP：除非 IP 声誉异常或区域迁移，否则不频繁更换。
- 区域：Tokyo 不稳定或目标服务体验差时，再切换 Singapore。

