# Agent notes for nz-energy-lakehouse

本仓库是公开的 Databricks 数据工程项目：新西兰电力批发结算电价，本机落地 CSV，再写入 Unity Catalog 的 Bronze / Silver / Gold。

## Where to change what

| 区域 | 路径 | 该写什么 | 不该写什么 |
|------|------|----------|------------|
| 门面 | `README.md` | 中英双语：问题、数据、流向、许可、开发说明 | 第三方课程原文；尚未算出来的「业务洞察」 |
| 合同 | `AGENTS.md` | 目录、硬约束、commit 规则 | 本机 Python 路径、workspace URL、个人 catalog |
| 本机覆盖 | `AGENTS.local.md` | 本机路径与个人 catalog（gitignore） | 提交进 git |
| 代码 | `src/land/`、`src/pipeline/` | 本机 lander、Lakeflow 转换 | 从 Free Edition 计算里 `requests` 打 EMI |
| Bundle | 根 `databricks.yml` + `resources/*.yml` | 已有 pipeline / Job 的部署合同 | 空 YAML；未 bind 就 `bundle deploy` |
| 落地缓存 | `data/landing/` | EMI CSV（gitignore 内容） | `git add` CSV |
| 说明图 | `docs/` | 架构说明、以后的看板截图 | 第三方课程截图或课件 HTML |

先读本文件 + `README.md`，再改代码。本机差异只放 `AGENTS.local.md`（可从 `AGENTS.local.md.example` 复制）。

## 目录架构

```text
src/land/          # Windows：下载 EMI CSV，上传 UC Volume
src/pipeline/      # Lakeflow / Spark Declarative Pipelines
databricks.yml     # Declarative Automation Bundles 根合同
resources/         # pipeline / Job YAML
docs/
data/landing/      # 本地 CSV 缓存（内容 gitignore）
README.md          # 中英双语门面
AGENTS.md
AGENTS.local.md    # gitignore
LICENSE            # 代码 MIT
```

## 硬约束（不得写反）

| 项 | 值 |
|----|-----|
| 问题 | 工作日 NZ 时间 17:00 之后，哪些节点 final energy price 尖峰 |
| v1 数据 | `FinalEnergyPrices` 最近 90 个**日**文件 + 当前 `NetworkSupplyPointsTable` |
| 增量 | 日文件；同一天 interim（`_I`）让位给 final |
| 落地 | **本机下载** → UC Volume。Free Edition 出网有白名单，禁止集群直拉 blob/API |
| UC 公开名 | `nz_energy.bronze` / `nz_energy.silver` / `nz_energy.gold` |
| 数据许可 | EMI CC BY 4.0；署名 `www.emi.ea.govt.nz provided by the Electricity Authority (New Zealand)` |
| 代码许可 | MIT（见 `LICENSE`） |
| 版权 | 只提交本仓原创代码与说明。不要粘贴第三方培训课程、付费 notebook 或其译本 |
| 忽略 | `data/landing` 下 CSV、`.env`、`.cursor/`、`AGENTS.local.md`。禁止 `git add -f` |
| 产品名 | Lakeflow pipelines、Spark Declarative Pipelines、Git folders、Declarative Automation Bundles、Lakeflow Jobs。不要把已更名的旧称（DLT、Repos、Asset Bundles）写成现行名 |
| 日期 | 用真实 author/committer 时间。不要设置 `GIT_AUTHOR_DATE` / `GIT_COMMITTER_DATE` |

本仓只包含这个项目的代码与文档。聊天记录、本机密钥、其他目录里的材料都不要加进来。

## Do not

- 把 EMI CSV、密钥、workspace token 推进 git
- 在 Databricks 计算里直连任意公网 API / EMI blob
- 把第三方课程练习改名后当作本仓作品
- 未对现有 pipeline / Job 做 `bundle deployment bind` 就 `databricks bundle deploy`（会另起一条 ETL pipeline）
- `git push`、打 tag、对忽略文件 `git add -f`
- 给 commit 加 Cursor / Copilot 的 `Co-authored-by`
- 改写历史提交日期

## After each change (commit workflow)

完成一轮改动、未发现问题、且用户未说先不提交时再 commit。

1. Conventional Commits 的 **summary（subject）**
2. **description 写 1–3 句**：为什么改、边界是什么。不要空 body，也不要写成变更清单长文
3. **不要** `git push`；由用户实机检查后自行推送或撤回
4. 改动跨边界时分批 commit（例如 `.gitignore` + `LICENSE` / `README.md` / `AGENTS.md`）

若改动有明显问题或未完成，则先修或说明，不要空提交，也不要打 tag。

### 资源与 gitignore

- **禁止**对忽略规则命中的文件使用 `git add -f` / `git add --force`
- 勿提交密钥、`.env`、账号 cookie、Databricks token
- 原始 EMI CSV 只存在 `data/landing/` 或 Volume，不进 git
