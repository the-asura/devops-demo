# DevOps 实践指南：让线上永远跑最新、可追溯的代码

> 演示仓库：https://github.com/the-asura/devops-demo
> 线上页面：https://the-asura.github.io/devops-demo/
> 读者：全体研发、测试、PM。不需要 DevOps 基础。

---

## 1. 我们为什么要谈这个

上次事故的时间线：

1. 同事 A 改了代码，提交并合入了主分支。
2. 同事 B 不知道 A 提交过，从自己电脑上的旧代码打包，部署到线上。
3. 线上跑的是旧代码，A 的修复没生效，出了事故。
4. 排查时没人能立刻说清楚线上到底是哪一版。

这不是 A 或 B 的错。**一个流程如果只靠"记得拉一下最新代码"才能不出事，那它迟早会出事。** 200 人的团队里，"记得"是不可靠的。

事故暴露的三个缺口：

| 缺口 | 表现 | 后果 |
|---|---|---|
| 没有单一事实来源 | 每个人电脑上都有一份代码，谁的是最新没人说得清 | 部署了旧代码 |
| 部署由人手动做 | 谁都能部，部之前没有强制的检查步骤 | 旧代码、没测过的代码都能上线 |
| 线上不自证身份 | 线上服务不显示自己是哪个 commit | 出事后靠猜，排查慢 |

---

## 2. DevOps 三句话讲清楚

DevOps 不是一个工具，也不是一个岗位，而是一条**从代码提交到线上运行的自动化流水线**，加上几条规矩。

- **CI（持续集成）**：每次有人提交代码，机器自动跑 lint、测试、构建。红了就不许合入。
- **CD（持续部署）**：部署由流水线做，不由人做。流水线只会从主分支最新 commit 部署，没有"部旧代码"这个选项。
- **可追溯**：每一个正在运行的服务，都能一眼看出自己是哪个 commit、什么时候、由谁构建的。发版打 tag，tag 就是版本号。

四条规矩：

1. 主分支受保护：不能直接推送，只能通过 PR 合入，CI 绿了才能合。
2. 生产部署只由流水线执行，输入只能是主分支。
3. 每个服务暴露自己的 commit SHA。
4. 对外发版必须打 tag，tag 必须落在主分支上，必须和代码里的版本号一致。

---

## 3. 这套流程能规避哪些情况

| 情况 | 没有流水线时 | 有流水线后 |
|---|---|---|
| 部署了旧代码（上次事故） | 靠人记得拉代码 | 流水线只从主分支最新 commit 构建，物理上不可能部旧的 |
| 没跑测试就上线 | 靠自觉 | CI 不绿不能合入主分支，合入即部署 |
| 本地未提交的改动被打包上线 | 经常发生，且无人知道 | 本地构建标记 DIRTY；流水线在干净机器上构建，不存在本地改动 |
| 两个人同时部署互相覆盖 | 谁后部谁赢 | 生产环境串行排队 |
| 直接往主分支推代码绕过 Review | 可以 | 分支保护直接拒绝，管理员也不例外 |
| force push 改写历史 | 可以 | 分支保护直接拒绝 |
| 出事后不知道线上是哪一版 | 靠猜 | 看页面 SHA 或 version.json；对外版本看 tag 和 Release |
| 版本号和代码对不上 | 常见 | 打 tag 时校验 tag 与 package.json 版本一致，不一致发版失败 |
| 在非主分支的 commit 上发版 | 可以 | Release 流水线校验 tag 必须在 main 上 |
| 上线、发版了没人知道 | 靠喊 | CI 通过、上线、发版三种事件都自动推飞书群 |
| CI 挂了没人管 | 不知道挂了 | CI 失败自动推飞书群，带提交人和日志链接 |

推翻条件：如果事故复盘发现 B 其实拉了最新代码，只是构建缓存出错，那根因在构建可复现性；"干净机器构建"仍覆盖这一点，但讲解重点应转向构建环境一致性。

---

## 4. 怎么做：以演示仓库为例

演示仓库是一个只显示"版本号 + commit SHA"的网页。麻雀虽小，流水线五脏俱全。

### 4.1 代码里的两个约定

- `scripts/build.mjs`：构建时把 commit SHA、构建时间、构建者写进页面和 `version.json`。本地构建如有未提交改动，标记 `DIRTY`。
- `src/version.mjs`：`isDeployable()` 只允许干净的 main 分支部署。这个函数有测试保护。

### 4.2 CI：`.github/workflows/ci.yml`

触发：每个 PR、每个非主分支推送。步骤：lint → test → build → 飞书通知（成功失败都发）。

### 4.3 CD：`.github/workflows/deploy.yml`

触发：主分支有新 commit。步骤：

1. 在干净机器上重新 lint、test、build，不信任任何本地产物。
2. 部署到 production 环境。
3. **回读线上 `version.json`，核对 SHA 等于本次 commit**，不一致判失败。
4. 飞书群通知：commit、作者、提交说明、线上地址、流水线链接。

`concurrency: production` 保证同一时间只有一个部署在跑。

### 4.4 发版：`.github/workflows/release.yml`

触发：推送 `v*` 形式的 tag。步骤：

1. 校验 tag 落在 main 上，否则失败。
2. 校验 tag 与 `package.json` 的版本号一致，否则失败。
3. 构建、打 zip、创建 GitHub Release，自动生成变更说明。
4. 飞书群通知。

发版命令：

```bash
git checkout main && git pull
git tag v1.0.0 && git push origin v1.0.0
```

### 4.5 分支保护

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["check"] },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

正式使用时把 `required_pull_request_reviews` 改成要求至少 1 人审核。

### 4.6 飞书通知的两种方式

流水线统一调用 `scripts/notify.sh`，它按顺序选择：

**方式一：lark-cli（bot 身份，推荐）**

1. 在飞书开放平台建一个企业自建应用，开通"获取与发送单聊、群组消息"权限，把机器人拉进通知群。
2. 存入仓库 secrets：

```bash
gh secret set LARK_APP_ID --body "cli_xxx"
gh secret set LARK_APP_SECRET --body "xxx"
gh secret set LARK_CHAT_ID --body "oc_xxx"
```

流水线会自动安装 lark-cli，用 bot 身份发 markdown 消息。

**方式二：群自定义机器人 webhook**

群设置 → 群机器人 → 添加自定义机器人，复制 webhook 和签名密钥：

```bash
gh secret set FEISHU_WEBHOOK --body "https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
gh secret set FEISHU_SECRET --body "签名密钥"
```

两种都没配时自动跳过，不影响流水线。

**本地巡检**：`scripts/notify-lark-cli.sh <chat_id>` 用你本机登录的 lark-cli，拉取线上 `version.json` 和主分支 SHA 比对，把结果发到群里。适合排查时手动跑，或放进定时任务。

### 4.7 分支和 PR 约定

- 分支名：`feature/{需求ID}-描述`、`fix/{需求ID}-描述`。
- PR 模板要求填关联需求和验收标准。
- 一个 PR 只做一件事。

---

## 5. 落地到公司（Gitee）

演示用 GitHub，公司用 Gitee，概念完全一样：

| GitHub | Gitee | 说明 |
|---|---|---|
| GitHub Actions | Gitee Go，或自建 Jenkins / GitLab Runner | 流水线执行器 |
| Branch protection | 仓库设置 → 分支保护 | 禁止直接推送、要求流水线通过 |
| Environments | Gitee Go 环境 / Jenkins 审批节点 | 生产部署前审批 |
| Release + tag | Gitee 发行版 + tag | 版本号唯一来源 |
| Pages | 公司现有部署目标 | 部署目标不重要，重要的是只由流水线部 |
| Secrets | Gitee Go 变量 / Jenkins Credentials | 存飞书密钥 |

分三步推，每步两周以内：

1. **可追溯**：每个服务在启动日志和健康检查接口输出 commit SHA。改动最小，出事时先看这个。
2. **主分支保护 + CI**：先在一个试点项目开。
3. **流水线部署 + tag 发版**：收回所有人的生产部署权限，只留流水线。上线和发版自动通知飞书群。

这三步也是《AI 项目管理平台》第一期的数据前提：平台要知道"线上跑的是什么"、"CI 有没有连续失败"、"有没有人绕过 Review"，这些数据只有流水线能提供。

---

## 6. 演示脚本（15 分钟）

准备：打开 GitHub 仓库页、线上页面、飞书演示群。

**第一幕：复现事故（5 分钟）**

1. A：改一行 `BANNER` 文案，走 PR 合入。飞书群先收到"CI 通过"，再收到"已上线"，线上页面 SHA 更新。
2. B：在一台没有 `git pull` 的目录里 `npm run build`，指出产物里的 SHA 是旧的，如有未提交改动还带 `DIRTY`。
3. 提问全场：如果 B 把这个产物传到服务器，线上是新是旧？谁能发现？

**第二幕：流水线怎么挡住它（10 分钟）**

4. B 尝试 `git push origin main`，被分支保护拒绝。
5. B 提交一个让测试失败的改动开 PR，CI 红，合并按钮灰掉，飞书群收到"CI 失败"。
6. B 修好，CI 绿，合并。Deploy 自动跑，最后一步核对线上 SHA，飞书群收到"已上线"。
7. 打 tag `v1.0.1` 推上去，Release 流水线跑完，GitHub 出现 Release 页面和 zip 产物，飞书群收到"发版"。
8. 跑 `scripts/notify-lark-cli.sh`，群里出现"主分支 vs 线上：一致"。
9. 收尾：回到事故时间线，逐条指出哪一步现在会被拦住。

---

## 7. 常见问题

**流水线会不会拖慢上线？** 演示仓库整条流水线不到两分钟。真实项目的构建时间本来就要花，流水线只是把它从某个人的电脑挪到机器上。

**紧急修复怎么办？** 一样走 PR，找人秒批。紧急时绕过流程，正是事故最容易发生的时候。

**分支保护把管理员也挡住了，太严了？** `enforce_admins` 是故意的。规矩对所有人生效才是规矩。

**我们没有测试怎么办？** 先把 lint 和构建放进 CI，测试逐步补。一个只做构建的流水线，也能挡住上次那种事故。
