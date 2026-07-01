# scripts

这里放“可复用、脱敏、可审计”的脚本模板。

## 安全边界

不要在脚本中保存：

- AWS access key / secret key / session token
- SSH 私钥内容
- VLESS UUID
- Reality private key
- short id
- 完整 VLESS URI
- 客户端订阅链接
- 二维码或完整客户端导出配置

## 推荐方式

- 提交 `.example.ps1` / `.example.sh` 模板。
- 真正运行的 `.local.ps1` / `.local.sh` 文件放在本机，不提交。
- 敏感参数通过 AWS CLI 登录态、环境变量、密码管理器或交互输入提供。
- 脚本输出前检查日志，避免把密钥打印到终端历史或复制进文档。

## 后续计划

计划补充：

```text
lightsail-create.example.ps1
server-init.example.sh
xray-install.example.sh
```

这些脚本会优先自动化基础设施和系统初始化；节点密钥生成与客户端链接生成默认只做临时输出，不落盘。
