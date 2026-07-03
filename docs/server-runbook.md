# 服务端部署手册

> 本手册只保存脱敏部署步骤。不要写入 AWS 凭证、SSH 私钥、VLESS UUID、Reality private key、short id、订阅链接或完整节点 URI。
> 状态：人工部署参考。当前推荐的脚本化初次部署入口见 [quickstart.md](quickstart.md)。

## 目标方案

```text
AWS Lightsail Global
Ubuntu 24.04 LTS 或 22.04 LTS
Static IP
Xray-core
VLESS Reality
TCP 443
systemd
Windows v2rayN
```

## 部署原则

- 不安装 Web 管理面板，降低攻击面。
- 服务端只运行 Xray-core 和系统必要服务。
- Lightsail 防火墙只开放必要端口。
- 所有密钥只保存在密码管理器或本机安全位置。
- 本仓库只保存手册、脱敏记录、脚本骨架和测试模板。

## 1. 创建 Lightsail 实例

建议配置：

| 项目 | 建议 |
| --- | --- |
| 区域 | Tokyo，备用 Singapore |
| 系统 | Ubuntu 24.04 LTS，备用 Ubuntu 22.04 LTS |
| 规格 | $5/月起步 |
| IPv4 | 绑定 Static IP |
| 备注 | 实例名使用可识别但不暴露用途的名称 |

Lightsail 防火墙：

| 端口 | 协议 | 用途 | 建议 |
| --- | --- | --- | --- |
| 22 | TCP | SSH | 初期开放，稳定后限制来源 IP |
| 443 | TCP | VLESS Reality | 开放 |

## 2. 基础系统初始化

登录服务器后执行：

```bash
sudo apt update
sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Shanghai
sudo reboot
```

重连后确认：

```bash
lsb_release -a
timedatectl
ip addr
```

## 3. SSH 加固

先确认当前密钥登录可用，再考虑关闭密码登录。

建议项：

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sshd -t
sudo systemctl reload ssh
```

可选加固项：

```text
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

注意：修改 SSH 前保留一个已登录会话，避免把自己锁在服务器外。

## 4. 安装 Xray-core

使用 Xray-core 官方安装方式或可审计的安装脚本。安装前记录脚本来源和日期，避免复制来历不明的一键脚本。

安装后确认：

```bash
xray version
sudo systemctl status xray
```

常见路径：

```text
/usr/local/bin/xray
/usr/local/etc/xray/config.json
/etc/systemd/system/xray.service
```

实际路径以安装结果为准，并写入 `docs/deployment-record.md`。

## 5. 生成节点参数

在服务器上生成参数，但不要把结果写入本仓库。

需要保存到密码管理器的内容：

| 类型 | 是否可入仓库 | 存放建议 |
| --- | --- | --- |
| VLESS UUID | 否 | 密码管理器 |
| Reality private key | 否 | 密码管理器 |
| Reality public key | 建议脱敏 | 密码管理器或部署记录脱敏备注 |
| short id | 否 | 密码管理器 |
| 完整分享链接 | 否 | 密码管理器 |

命令示例：

```bash
xray uuid
xray x25519
openssl rand -hex 8
```

## 6. 配置 Xray

配置目标：

| 项目 | 值 |
| --- | --- |
| inbound protocol | vless |
| listen | 0.0.0.0 |
| port | 443 |
| network | tcp |
| security | reality |
| flow | xtls-rprx-vision |
| outbound | freedom |

配置文件中会包含敏感字段，因此不要复制到本仓库。

建议只在部署记录中写：

```text
配置文件路径：/usr/local/etc/xray/config.json
敏感参数位置：密码管理器条目 <name>
Reality dest/serverName：<public-or-redacted>
```

## 7. 启动与验证

```bash
sudo xray run -test -config /usr/local/etc/xray/config.json
sudo systemctl enable xray
sudo systemctl restart xray
sudo systemctl status xray
sudo ss -lntp
```

期望结果：

- `xray run -test` 通过。
- `systemctl status xray` 显示运行中。
- `ss -lntp` 能看到 TCP 443 监听。
- Lightsail 防火墙允许 TCP 443。

## 8. Windows v2rayN 验证

第一阶段建议：

1. v2rayN 手动添加 VLESS Reality 节点。
2. 先用系统代理验证连通性。
3. 再启用路由规则或 TUN。
4. 按 `docs/test-record-template.md` 记录结果。

不要把 v2rayN 导出的完整配置、二维码或节点链接保存到仓库。

## 9. 故障排查

服务端：

```bash
sudo systemctl status xray
sudo journalctl -u xray --no-pager -n 100
sudo xray run -test -config /usr/local/etc/xray/config.json
sudo ss -lntp
```

客户端：

```text
确认地址、端口、UUID、public key、short id、serverName、flow、fingerprint 是否一致。
先测试系统代理，再测试 TUN。
先测试全局代理，再测试规则分流。
```

云侧：

```text
确认实例运行中。
确认 Static IP 绑定到当前实例。
确认 Lightsail 防火墙开放 TCP 443。
确认本地网络没有阻断目标端口。
```
