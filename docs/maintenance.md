# 维护手册

> 维护记录同样必须脱敏。不要保存明文密钥、token、订阅链接、SSH 私钥或完整节点 URI。

## 周期性检查

| 周期 | 检查项 | 说明 |
| --- | --- | --- |
| 每周 | 服务状态 | `systemctl status xray` |
| 每周 | 日志异常 | `journalctl -u xray --no-pager -n 100` |
| 每月 | Lightsail 账单 | 确认实例、流量费用，以及已启用时的 Static IP |
| 每月 | 系统更新 | 安全更新优先 |
| 每月 | 客户端版本 | v2rayN 及其 core、geo 数据更新 |
| 变更后 | 全量测试 | 按本页排障顺序完成连通性与客户端检查 |

## 常见维护命令

```bash
sudo systemctl status xray --no-pager
sudo systemctl restart xray
sudo journalctl -u xray --no-pager -n 100
sudo ss -lntp
```

## 故障排查顺序

1. 确认 Lightsail 实例运行中。
2. 如果启用了 Static IP，确认它仍绑定到目标实例；默认快速重建模式不使用 Static IP。
3. 确认 Lightsail 防火墙允许 TCP 443。
4. 确认服务端进程正在监听 TCP 443。
5. 确认客户端节点参数没有被误改。
6. 确认 TUN / Service Mode / DNS 设置正常。
7. 分别测试直连、规则代理、全局代理，缩小问题范围。

## 轮换建议

- SSH 私钥：怀疑泄漏时立即轮换。
- VLESS UUID / Reality key：客户端设备丢失、配置泄漏、异常连接时轮换。
- 节点 IP：默认以重建获得新 IP；只有启用 Static IP 时才在区域迁移或 IP 声誉异常时评估更换。
- 区域：Tokyo 不稳定或目标服务体验差时，再切换 Singapore。


## v2rayN / Reality 排障

- `Test-NetConnection <node-ip> -Port 443` 必须显示 `TcpTestSucceeded=True`，且 `InterfaceAlias` 不应是其他代理的 TUN 网卡。
- 如果本机同时运行其他代理或 TUN，用 `scripts/Manage-LightsailProxy.ps1 -Action AddBypassRoute` 给节点 IP 加直连路由，避免测试流量绕进其他 TUN。
- v2rayN 延迟 `-1ms` 只能说明探测失败，不等同于 AWS 端口不通；继续看本地 Xray 日志和服务端 `journalctl -u xray`。
- 客户端日志出现 `proxy/vless/outbound ... [EOF]`，服务端日志出现 `REALITY ... handshake did not complete successfully`，通常是 Reality `serverName/dest`、public key、shortId 或客户端未重新导入导致。
- 本项目默认 Reality `serverName/dest` 使用 `www.cloudflare.com`，客户端 URL 包含 `spx=%2F`。
- Windows `curl.exe` 通过代理测试 HTTPS 时，如果出现 `CRYPT_E_REVOCATION_OFFLINE`，可用 `--ssl-no-revoke` 排除本机 Schannel 吊销检查干扰。
