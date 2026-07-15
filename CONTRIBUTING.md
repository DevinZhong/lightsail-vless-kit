# 贡献指南

感谢贡献。本项目面向个人、可审计的 Lightsail 节点脚本，不接受多用户面板、远程订阅服务或会收集用户凭据的功能。

## 提交前

1. 不提交 `.env.local`、`secrets.local.env`、`output/`、私钥、节点 URL 或真实 IP。
2. 运行 `./scripts/Validate-Repository.ps1`。
3. Bash 改动还应运行 `bash -n scripts/lightsail-proxy.sh scripts/bash/*.sh scripts/internal/*.sh`。
4. 在 PR 中说明支持的平台、测试命令和未覆盖的真实 AWS 行为。

## 兼容性原则

- PowerShell 是主维护路径；Bash 功能须在文档中标明覆盖范围。
- 不把未经验证的区域、套餐或客户端行为写成保证。
- 对删除、重建、密钥或路由改动，必须保留明确确认和安全回退路径。
