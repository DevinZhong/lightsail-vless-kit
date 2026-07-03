# 重建与删除指引

> 重建和删除都会影响正在使用的节点。确认客户端有切换窗口后再操作。

## 什么时候重建

适合重建的情况：

- 当前 IP 不稳定或目标服务体验明显变差。
- cloud-init 或服务端配置损坏，修复成本高于重建。
- 想换区域、规格或系统版本。

不一定需要重建的情况：

- 只是 v2rayN 延迟显示 `-1ms`。
- 本地 TUN、DNS 或路由规则疑似异常。
- AWS 防火墙漏开端口。

重建前先跑：

```powershell
.\scripts\Test-NodeConnectivity.ps1
```

## 快速重建

默认交互式确认：

```powershell
.\scripts\Rebuild-LightsailProxy.ps1
```

无人值守或你已经确认要删旧建新：

```powershell
.\scripts\Rebuild-LightsailProxy.ps1 -Yes
```

这个脚本会：

1. 删除 `.env.local` 指向的 Lightsail 实例。
2. 等待一小段时间。
3. 使用同一份本地密钥和配置创建替代实例。
4. 重新生成 `output/` 下的客户端 URL。

重建后服务器 IP 会变化，v2rayN 需要重新导入新 URL，或手动更新节点地址。

## 只删除实例

交互式确认：

```powershell
.\scripts\Remove-LightsailProxy.ps1
```

跳过确认：

```powershell
.\scripts\Remove-LightsailProxy.ps1 -Yes
```

删除脚本只删除 Lightsail 实例，不删除：

- 本地 `.env.local`
- 本地 `secrets.local.env`
- SSH 私钥
- `output/` 下已生成的客户端文件

不用节点时应删除实例。Lightsail `stop` 不等于完全停止计费。

## Static IP 注意事项

项目默认 `USE_STATIC_IP=false`，因为“IP 不行就快速重建”的模式通常希望拿到新 IP。

如果开启 Static IP：

- 删除实例前确认是否还需要保留 Static IP。
- 不再使用时释放 Static IP，避免额外费用。
- `RELEASE_STATIC_IP_ON_DELETE=true` 前先确认不会误删仍在使用的地址。

## 重建后检查清单

```powershell
.\scripts\Test-NodeConnectivity.ps1
```

然后确认：

- TCP 443 可达。
- `output/vless-reality-url.txt` 已更新。
- v2rayN 已重新导入或更新节点。
- ChatGPT / GitHub / Google 等目标服务通过。
- 国内网站直连正常。

如需记录变更，只写脱敏信息到 [deployment-record.md](deployment-record.md)。
