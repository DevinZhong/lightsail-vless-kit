# 发布清单

本项目只发布可审计的个人固定出口脚本模板，不发布真实节点或订阅服务。

## 发布前

1. 运行 `./scripts/Validate-Repository.ps1`；有 Bash 环境时，运行 `bash -n scripts/bash/*.sh scripts/internal/*.sh cloud-init/cloud-init.tpl.sh`。
2. 确认 `git status --ignored` 中的 `.env.local`、`secrets.local.env`、`output/` 内容没有被暂存。
3. 用新的 AWS 账号或隔离的测试资源，按 [quickstart.md](quickstart.md) 从 clone 到创建完成一次验证；创建后删除测试实例。
4. 审查 `XRAY_VERSION` 的上游发行说明，并确认对应 release 的 `.dgst` 校验文件可用。不要恢复“自动使用 latest”。
5. 确认 GitHub private vulnerability reporting 已启用，并检查 [SECURITY.md](../SECURITY.md) 的报告方式仍有效。
6. 检查 README 的范围、费用和合规说明没有作出稳定性、匿名性或绕过限制的承诺。

## 发布后

1. 用清晰的标签发布，例如 `v0.1.0`。
2. 变更 Xray 版本时，先在测试节点验证，再单独提交版本更新和验证记录。
3. 只在确有复现步骤时修复兼容性问题；v2rayN 辅助配置继续保持可选，不纳入服务器创建主链路。
