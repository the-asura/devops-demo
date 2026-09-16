# devops-demo

团队 DevOps / CI/CD 演示仓库。线上页面只显示一件事：**当前运行的 commit SHA**。

- 文档：[docs/DEVOPS.md](docs/DEVOPS.md)（概念、能规避什么、怎么做、演示脚本）
- 线上：https://the-asura.github.io/devops-demo/
- 规矩：主分支受保护 → PR 必须 CI 绿 → 合入即由流水线部署 → 部署后核对线上 SHA → 打 tag 发版 → 每一步飞书群通知

```bash
npm run lint && npm test && npm run build && npm run preview
scripts/notify-lark-cli.sh <飞书群 chat_id>   # 核对主分支与线上是否一致
git tag v1.0.0 && git push origin v1.0.0       # 发版
```
