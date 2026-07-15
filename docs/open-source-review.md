# 开源复用评估

## 结论

这个项目有开源复用价值，但更适合定位为“个人固定出口节点的可审计脚本模板”，而不是面向大众的一键机场/面板项目。

它的价值在于：

- 自动化 AWS Lightsail 创建、端口开放、cloud-init 初始化和客户端 URL 渲染。
- 默认不引入 Web 面板、Docker 或大型管理系统，攻击面小。
- 敏感信息边界相对清楚：AWS 凭证走本机 AWS CLI，代理密钥走本地 ignored 文件，渲染输出放 `output/`。
- Windows PowerShell 路径比较完整，适合 v2rayN 用户复用。

## 适合的受众

- 有 AWS 账号和基础命令行能力的个人用户。
- 想要一个低维护、可重建固定出口的人。
- 不想使用 3x-ui、v2ray-agent 或远程订阅服务的人。

不太适合：

- 完全零基础用户。
- 多用户售卖或共享节点场景。
- 需要 Web 面板、流量统计、账号管理、自动订阅发布的人。

## 当前发布门槛

必须做：

- 确认 `.env.local`、`secrets.local.env`、`output/` 内容没有被暂存或提交。
- 用新 clone 和隔离 AWS 测试资源跑通一次主流程，然后删除测试实例。
- 保持 Xray 版本固定，并验证上游 release 的 `.dgst` 校验文件；不要在部署时自动使用 latest。
- 运行 `scripts/Validate-Repository.ps1`，并在 Bash 环境做语法检查。
- 启用 GitHub private vulnerability reporting，并按 [releasing.md](releasing.md) 完成发布检查。

建议做：

- 把 PowerShell 标为主路径，Bash 标为兼容路径。
- 只在真实的兼容性需求出现后，再增加 ShellCheck 或 PSScriptAnalyzer；基础语法和模板检查已经在 CI 中覆盖。
- 为每次 Xray 升级保留脱敏测试记录。

## 不建议开源的内容

- 真实部署记录。
- 真实客户端配置导出。
- v2rayN 数据库备份。
- 完整节点 URI、订阅文件、二维码。
- SSH 私钥、AWS key、任何 token。

## 维护成本判断

短期维护成本低，主要依赖：

- AWS Lightsail CLI 参数稳定性。
- Ubuntu cloud-init 行为。
- Xray 安装源可用性。
- v2rayN 配置结构变化。

最容易老化的是 v2rayN 配置数据库脚本。这个脚本对个人很有用，但开源后应明确标为“可选客户端辅助工具”，不要作为部署主链路的硬依赖。
