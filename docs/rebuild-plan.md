# 快速重建方案

> 用于 AWS 节点不可用、IP 声誉异常、区域迁移或服务端损坏时快速恢复。不要在脚本或文档中保存 AWS access key、secret key、SSH 私钥、VLESS UUID、Reality private key、short id、订阅链接或完整节点 URI。
> 状态：历史规划稿。当前实际操作入口见 [rebuild-and-delete.md](rebuild-and-delete.md)。本文保留用于理解设计取舍，不再作为主操作手册。

## 核心逻辑

是的，本项目适合维护一套“快速重建脚本”。

脚本负责自动化重复、低风险、可审计的动作：

1. 创建新的 Lightsail Ubuntu 实例。
2. 分配或绑定 Static IP。
3. 设置 Lightsail 防火墙端口。
4. 等待 SSH 可连接。
5. 执行基础系统初始化。
6. 安装 Xray-core。
7. 生成本地客户端 URL 和本地订阅文本。
8. 输出下一步人工操作清单。

脚本不负责保存或提交敏感内容：

- 不写 AWS 凭证。
- 不写 SSH 私钥。
- 不写 VLESS UUID。
- 不写 Reality private key。
- 不写完整客户端节点链接。
- 不生成可直接泄漏节点的二维码。

## 为什么保留人工确认

节点被封或不可用时，速度很重要，但完全自动生成并落盘所有配置容易引入泄漏风险。

建议边界：

| 动作 | 自动化 | 原因 |
| --- | --- | --- |
| 创建 Lightsail 实例 | 是 | 重复动作，适合脚本 |
| 绑定 Static IP | 是 | 重复动作，适合脚本 |
| 系统更新 | 是 | 标准动作 |
| 安装 Xray-core | 是 | 可审计脚本即可 |
| 生成 UUID / Reality key | 半自动 | 可生成，但只显示一次并立即存入密码管理器 |
| 写入 Xray config | 半自动 | 配置含敏感信息，不入仓库 |
| 生成客户端链接 | 半自动 | 只在本机临时生成，不保存 |
| 更新测试记录 | 人工 | 需要观察真实结果 |

## 推荐脚本分层

```text
scripts/
├── README.md
├── lightsail-create.example.ps1
├── server-init.example.sh
└── xray-install.example.sh
```

后续可以逐步补齐这些脚本：

| 脚本 | 运行位置 | 作用 |
| --- | --- | --- |
| `lightsail-create.example.ps1` | Windows 本机 | 调用 AWS CLI 创建实例、绑定 Static IP、开放端口 |
| `server-init.example.sh` | Ubuntu 服务器 | 系统更新、基础工具、时区、SSH 检查 |
| `xray-install.example.sh` | Ubuntu 服务器 | 安装 Xray-core、启用 systemd |

文件名使用 `.example`，表示这是模板。真正带有本机路径、实例名、密钥路径的运行脚本可以放在仓库外，或加入 `.gitignore`。

## AWS CLI 运行原则

本机需要预先配置 AWS CLI，但凭证不进入仓库：

```powershell
aws configure sso
# 或使用已有的 AWS 凭证链
aws sts get-caller-identity
```

重建脚本只读取当前 AWS CLI 登录态。

建议参数通过命令行传入：

```powershell
.\lightsail-create.local.ps1 `
  -Region ap-northeast-1 `
  -InstanceName <redacted-instance-name> `
  -StaticIpName <redacted-static-ip-name> `
  -KeyPairName <existing-keypair-name>
```

## 重建检查清单

### 云资源

| 检查项 | 状态 |
| --- | --- |
| 新实例创建成功 | 未完成 |
| Static IP 已绑定 | 未完成 |
| TCP 443 已开放 | 未完成 |
| SSH 可连接 | 未完成 |
| 旧实例保留或销毁策略已确认 | 未完成 |

### 服务端

| 检查项 | 状态 |
| --- | --- |
| Ubuntu 更新完成 | 未完成 |
| Xray-core 安装完成 | 未完成 |
| 新 VLESS UUID 已生成并存入密码管理器 | 未完成 |
| 新 Reality key 已生成并存入密码管理器 | 未完成 |
| Xray config 测试通过 | 未完成 |
| systemd 服务运行中 | 未完成 |
| TCP 443 正在监听 | 未完成 |

### 客户端

| 检查项 | 状态 |
| --- | --- |
| v2rayN 新节点已添加 | 未完成 |
| 系统代理测试通过 | 未完成 |
| TUN 测试通过 | 未完成 |
| OpenAI / ChatGPT 测试通过 | 未完成 |
| GitHub 测试通过 | 未完成 |
| Google 测试通过 | 未完成 |


## 客户端更新策略

本项目不维护远程固定订阅地址。

重建频率预期较低时，最简单可靠的方式是每次重建后生成本地文件，然后手动导入客户端：

```text
output/vless-reality-url.txt
output/hysteria2-url.txt
output/subscription.txt
```

这些文件都包含完整代理连接凭据，必须保留在 `.gitignore` 中，不提交、不同步到不可信位置。

如果后续发现节点频繁失效，说明这个低维护方案本身不再适合，应重新评估服务商、区域、协议和使用方式，而不是继续叠加复杂订阅发布逻辑。
## 旧节点处理

新节点稳定后再处理旧节点：

1. 确认新节点至少通过一次完整测试。
2. 导出或记录旧节点脱敏信息。
3. 停止旧 Xray 服务。
4. 释放不用的 Static IP，避免额外费用。
5. 删除旧实例。
6. 在 `docs/deployment-record.md` 写入变更记录。

## 最小恢复目标

节点故障时，先恢复最小可用能力：

```text
Windows v2rayN
  -> 新 VLESS Reality 节点
  -> 系统代理或 TUN
  -> ChatGPT / OpenAI / GitHub 可访问
```

复杂规则、备用客户端、订阅整理可以在恢复后再做。

