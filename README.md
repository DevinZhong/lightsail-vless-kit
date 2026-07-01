# personal-fixed-exit

低成本、低维护的个人固定外网出口环境项目文档。

本项目用于记录和维护一套个人自建固定出口，目标不只服务 Codex/ChatGPT，也覆盖日常开发访问、GitHub、Google 等常用外网访问场景。

## 目标架构

- 云厂商：AWS Lightsail Global
- 首选区域：Tokyo
- 备选区域：Singapore
- 实例规格：Linux，$5/月起步
- 出口 IP：Lightsail Static IP
- 服务端协议：VLESS Reality over TCP 443
- Windows 客户端：v2rayN 首选，Hiddify 备用，Clash Verge Rev 用于复杂规则/TUN 场景
- 分流目标：OpenAI / ChatGPT / Codex / GitHub / Google 等常用域名按规则走自建出口

## 目录结构

```text
.
├── README.md
├── docs/
│   ├── deployment-record.md
│   ├── client-config-template.md
│   ├── test-record-template.md
│   ├── maintenance.md
│   ├── server-runbook.md
│   └── rebuild-plan.md
├── scripts/
│   └── README.md
└── templates/
    ├── hiddify-notes.md
    └── clash-verge-rev-rules.yaml
```

## 绝对不要保存的内容

不要把以下任何内容写入本目录、提交到 git、贴到 issue 或同步到不可信云盘：

- 明文 UUID / private key / short id / Reality private key
- VLESS 分享链接、订阅链接、完整节点 URI
- SSH 私钥、AWS access key、AWS secret key
- OpenAI / GitHub / Google / Cloudflare 等 token
- 真实服务器登录密码、控制台临时凭证
- 能直接还原节点连接能力的二维码、截图或配置导出

推荐做法：

- 敏感信息只放在密码管理器、本机受保护笔记或临时命令行环境变量中。
- 文档中只记录脱敏信息，例如 `x.x.x.123`、`uuid: <stored-in-password-manager>`。
- 需要协作时，只分享结构、步骤、错误信息和脱敏日志。

## 推荐部署流程

1. 创建 Lightsail Linux 实例，区域首选 Tokyo，不可用时选 Singapore。
2. 绑定 Static IP，并记录实例名、区域、脱敏 IP。
3. 配置系统基础安全项：更新系统、SSH 加固、防火墙仅开放必要端口。
4. 安装并配置 Xray-core，启用 VLESS Reality TCP 443。
5. 在 Windows v2rayN 中导入节点，先用系统代理验证，再启用 TUN 或规则分流。
6. 添加规则：OpenAI、ChatGPT、Codex、GitHub、Google 等域名走自建出口。
7. 按 `docs/test-record-template.md` 记录连通性、出口 IP、DNS、常用站点访问结果。

## 维护原则

- 优先保持简单：单实例、单静态 IP、少量规则、少量自动化。
- 每次改动先记录：改动时间、原因、命令摘要、验证结果。
- 只记录可公开的信息；密钥和订阅一律引用“存放位置”，不记录值。
- 定期检查实例费用、流量、系统更新和服务状态。
- 脚本只做可复用的基础设施动作，不保存 AWS 凭证、节点密钥、SSH 私钥或完整客户端配置。

## 快速重建思路

如果现有 AWS 节点不可用，目标是用脚本快速完成“创建实例、基础初始化、生成本地客户端 URL”的重复动作，再手动导入 v2rayN。重建频率预期较低，因此不维护远程固定订阅地址。

重建流程记录在 `docs/rebuild-plan.md`。脚本放在 `scripts/`，但只保存脱敏脚本骨架；运行时通过 AWS CLI 当前登录态、环境变量或本机凭证链读取权限，不把凭证写入仓库。代入真实参数的 `.local` 脚本应放在仓库外或被 `.gitignore` 忽略。

## 当前状态

- 阶段：文档初始化
- 云实例：未创建
- Static IP：未绑定
- 服务端：未部署
- Windows 客户端：未配置

