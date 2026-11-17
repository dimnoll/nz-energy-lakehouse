# nz-energy-lakehouse

[English](#english) | [中文](#中文)

Personal Databricks data-engineering project: New Zealand wholesale electricity prices, landed on a laptop, stored as Delta in Unity Catalog, and shaped through a Bronze / Silver / Gold pipeline.

**Status:** local EMI lander works (`src/land/download_emi.py`), including monthly `Generation_MD` files that overlap the price window. One Lakeflow pipeline in `src/pipeline/` has been run for prices and generation (Bronze / Silver / Gold). Generation Gold was checked: weekdays in the monthly files, not clipped to the 90-day price start. Lakeflow Job `EMI daily refresh` triggers that pipeline on a daily Auckland schedule. One AI/BI dashboard has two pages: price spikes and generation mix. A Declarative Automation Bundle (`databricks.yml`) describes that pipeline and Job for `databricks bundle validate`; it is not auto-deployed. CSV cache stays in `data/landing/` and is gitignored.

---

## English

### Question

On weekdays, which grid nodes spike in **final energy price** after 17:00 NZ time?

A second question, same evening window: does **national generation mix** (EMI `Fuel_Code`, kWh) shift after 17:00 versus daytime? That is a separate Gold table, not a column on the node ranking.

v1 prices use half-hour **FinalEnergyPrices** (last 90 daily files) plus the **NetworkSupplyPoints** dimension. Generation uses monthly **Generation_MD** files that overlap that window (they lag the daily prices).

### Data

| Dataset | Grain | v1 window |
| --- | --- | --- |
| [Final energy prices](https://www.ea.govt.nz/data-and-insights/datasets/wholesale/dispatch-and-pricing/final-energy-prices/) | node × trading period × day | last 90 daily CSVs (~300 KB each) |
| Network supply points (`MappingsAndGeospatial/NetworkSupplyPointsTable`) | point of connection | current snapshot |
| [Generation by plant](https://www.emi.ea.govt.nz/Wholesale/Datasets/Generation/Generation_MD) (`Generation_MD`) | plant × day × TP1–TP50 (kWh, wide) | monthly CSVs overlapping the price window |

Files come from the Electricity Authority EMI Azure blob (`emidatasets.blob.core.windows.net/publicdata`). Download on Windows; **do not** fetch from Databricks Free Edition compute (outbound access is allowlisted). Upload into a Unity Catalog Volume, then run the pipeline.

Interim price files (`*_I.csv`) are replaced by finals; the lander must prefer the final file for a given day.

Data licence: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Attribution: *www.emi.ea.govt.nz provided by the Electricity Authority (New Zealand)*.

Raw CSVs are not committed. See `data/landing/` (gitignored contents).

### Layout

```text
Windows lander  →  UC Volume  →  nz_energy.bronze
                              →  nz_energy.silver   (types, expectations)
                              →  nz_energy.gold     (weekday evening-peak KPIs)
                              →  AI/BI dashboard
Lakeflow Job `EMI daily refresh`  (daily 07:00 Pacific/Auckland; does not fetch EMI)
```

Lakeflow graph (Auto Loader CSV sources, then streaming tables and materialized views). The workspace DAG screenshot below is from the first successful prices-only run; generation tables join after the Volume upload.

```mermaid
flowchart LR
  nspCsv["Volume NSP CSV"] --> nspRaw["bronze.network_supply_points_raw"]
  priceCsv["Volume prices CSV"] --> priceRaw["bronze.final_energy_prices_raw"]
  genCsv["Volume Generation_MD CSV"] --> genRaw["bronze.generation_md_raw"]
  nspRaw --> nspCur["silver.nsp_current"]
  priceRaw --> prices["silver.prices"]
  nspCur --> loc["silver.prices_with_location"]
  prices --> loc
  loc --> daily["gold.weekday_evening_node_prices"]
  daily --> ranked["gold.evening_spike_ranked"]
  genRaw --> genPer["silver.generation_periods"]
  genPer --> fuelMix["gold.weekday_evening_fuel_mix"]
```

Workspace DAG after the first successful run:

![Lakeflow pipeline DAG after the first successful workspace run](docs/lakeflow-pipeline-dag.png)

Lakeflow Job `EMI daily refresh` wraps that pipeline (one pipeline task). It is scheduled daily at 07:00 `Pacific/Auckland`. The screenshot is a manual run that succeeded; Databricks compute still does not fetch EMI, and Volume upload stays manual.

![Lakeflow Job EMI daily refresh: one successful pipeline-task run](docs/lakeflow-job-emi-daily-refresh.png)

AI/BI page `Weekday evening spikes`: top 20 nodes by mean evening/daytime ratio, plus the daily series for `WTK0111`. A few extreme days lift the window mean; typical days sit much lower.

![AI/BI dashboard: top 20 evening/daytime ratios and WTK0111 daily series](docs/ai-bi-weekday-evening-spikes.png)

AI/BI page `Weekday evening mix` (same dashboard): daily evening kWh share for `Hydro`, plus mean evening share by EMI `Fuel_Code`. `Hydro` and `HYD` stay separate labels. This page is not a price chart.

![AI/BI dashboard: Hydro evening kWh share and mean evening share by fuel](docs/ai-bi-weekday-evening-mix.png)

| Path | Role |
| --- | --- |
| `src/land/` | Local EMI download (`download_emi.py`). Volume upload is still manual. |
| `src/pipeline/` | Lakeflow / Spark Declarative Pipelines SQL (`01_bronze.sql` → `04_generation.sql`). Workspace run notes: `src/pipeline/README.md`. |
| `databricks.yml` | Bundle identity and the single `workspace` target. Host/token stay in the local CLI profile. |
| `resources/` | Pipeline and Job YAML (`emi_lakeflow.pipeline.yml`, `emi_daily_refresh.job.yml`). |
| `docs/` | Pipeline DAG, Job run, and AI/BI dashboard screenshots (spikes and mix pages) |
| `data/landing/` | Local CSV cache (ignored) |

Catalog/schema names above are the public contract. A personal workspace catalog belongs in untracked `AGENTS.local.md`.

v1 Gold grain: weekday date × node, evening mean (TradingPeriod ≥ 35, 17:00 NZ) versus daytime mean (TP 15–34). Ranked node table is `nz_energy.gold.evening_spike_ranked`. Dashboard page `Weekday evening spikes` uses that rank plus the daily series for a Waitaki node (`WTK0111`).

Generation Gold grain: weekday date × EMI `Fuel_Code`, evening kWh share versus daytime share. Table: `nz_energy.gold.weekday_evening_fuel_mix`. Codes such as `Hydro` and `HYD` are left as EMI labelled them. The checked window is weekdays 2026-08-03 to 2026-10-30 (the landed monthly files), which starts earlier than the 90-day price files.

### Development

From the repo root, `databricks bundle validate` checks the bundle against the local CLI profile. Do **not** `databricks bundle deploy` unless those YAML resources are bound to the existing workspace pipeline and Job. An unbound deploy can create a second ETL pipeline. Databricks compute still does not fetch EMI.

Code and docs in this repository are written in Cursor. Design choices, data-quality rules, and any published insights are reviewed before they count as the project’s conclusions. Git commits are authored by the repository owner; they are not machine-attributed.

This repo is original portfolio work. It is not a copy of Databricks Academy notebooks.

### Licence

- Repository code: [MIT](LICENSE)
- EMI datasets: CC BY 4.0, Electricity Authority (New Zealand)

---

## 中文

个人 Databricks 数据工程项目：新西兰电力批发市场结算电价。CSV 在本机落地，写入 Unity Catalog 的 Delta 表，再走 Bronze / Silver / Gold。

**当前状态：** 本机 EMI 下载脚本已可跑（`src/land/download_emi.py`），也包括与价格窗口重叠的 `Generation_MD` 月文件。`src/pipeline/` 里那条 Lakeflow 已跑通价格和发电的 Bronze / Silver / Gold。发电 Gold 已核对：窗口是月文件里的工作日，没有裁成价格那 90 天的起点。Lakeflow Job `EMI daily refresh` 按奥克兰时间每天触发。同一张 AI/BI 看板两页：节点尖峰和发电结构。根目录 `databricks.yml` 用 Declarative Automation Bundles 描述这条 pipeline 和 Job，供 `databricks bundle validate`；不会一 push 就部署。CSV 缓存在 `data/landing/`，不进 git。

### 问题

工作日、新西兰时间 **17:00 之后**，哪些节点的 **final energy price** 出现尖峰？

同一晚间窗口的第二句：全国 **发电结构**（EMI `Fuel_Code`，kWh）相对日间有没有变？这是另一张 Gold 表，不是节点排名上的一列。

v1 价格用半小时 **FinalEnergyPrices**（最近 90 个日文件）和 **NetworkSupplyPoints**。发电用与该窗口重叠的 **Generation_MD** 月文件（比日价格滞后）。

### 数据

| 数据集 | 粒度 | v1 窗口 |
| --- | --- | --- |
| [Final energy prices](https://www.ea.govt.nz/data-and-insights/datasets/wholesale/dispatch-and-pricing/final-energy-prices/) | 节点 × 交易时段 × 日 | 最近 90 个日 CSV（每个约 300 KB） |
| 供电点表（`MappingsAndGeospatial/NetworkSupplyPointsTable`） | 并网点 | 当前一份快照 |
| [分厂发电量](https://www.emi.ea.govt.nz/Wholesale/Datasets/Generation/Generation_MD)（`Generation_MD`） | 电厂 × 日 × TP1–TP50（kWh，宽表） | 与价格窗口重叠的月 CSV |

文件来自 Electricity Authority EMI 的 Azure blob。在 Windows 上下载；**不要**从 Databricks Free Edition 计算里直接拉网（出网有白名单）。上传到 Unity Catalog Volume 后再跑流水线。

带 `_I` 后缀的是 interim 价，定稿后会被 final 文件替换；lander 同一天只保留 final。

数据许可：[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。署名：*www.emi.ea.govt.nz provided by the Electricity Authority (New Zealand)*。

原始 CSV 不进 git，见 `data/landing/`（内容已忽略）。

### 流向

```text
本机 lander  →  UC Volume  →  nz_energy.bronze
                           →  nz_energy.silver   （类型、质量期望）
                           →  nz_energy.gold     （工作日晚高峰 KPI）
                           →  AI/BI 看板
Lakeflow Job `EMI daily refresh`  （每天 07:00 Pacific/Auckland；不拉 EMI）
```

Lakeflow 图（Auto Loader 读 CSV，再接 streaming table 与 materialized view）。下面 workspace DAG 截图是第一次只跑价格时的成功运行；发电表要等 Volume 上传后再进图。

```mermaid
flowchart LR
  nspCsv["Volume NSP CSV"] --> nspRaw["bronze.network_supply_points_raw"]
  priceCsv["Volume prices CSV"] --> priceRaw["bronze.final_energy_prices_raw"]
  genCsv["Volume Generation_MD CSV"] --> genRaw["bronze.generation_md_raw"]
  nspRaw --> nspCur["silver.nsp_current"]
  priceRaw --> prices["silver.prices"]
  nspCur --> loc["silver.prices_with_location"]
  prices --> loc
  loc --> daily["gold.weekday_evening_node_prices"]
  daily --> ranked["gold.evening_spike_ranked"]
  genRaw --> genPer["silver.generation_periods"]
  genPer --> fuelMix["gold.weekday_evening_fuel_mix"]
```

第一次成功跑通后的 workspace DAG：

![第一次成功跑通后的 Lakeflow pipeline DAG](docs/lakeflow-pipeline-dag.png)

Lakeflow Job `EMI daily refresh` 包着这条 pipeline（一个 pipeline task），按 `Pacific/Auckland` 每天 07:00 触发。截图是一次手动 Run 成功；计算端仍不拉 EMI，Volume 上传仍是人工。

![Lakeflow Job EMI daily refresh：一次成功的 pipeline-task 运行](docs/lakeflow-job-emi-daily-refresh.png)

AI/BI 页面 `Weekday evening spikes`：按晚间/日间均价比的前 20 名，以及 `WTK0111` 的按日序列。窗口均值会被少数极端日抬高，多数日子低得多。

![AI/BI 看板：前 20 名晚间/日间比与 WTK0111 按日序列](docs/ai-bi-weekday-evening-spikes.png)

同一看板的 `Weekday evening mix`：`Hydro` 的按日晚间 kWh 份额，以及按 EMI `Fuel_Code` 的窗口均份额。`Hydro` 与 `HYD` 仍分开。这一页不是电价图。

![AI/BI 看板：Hydro 晚间 kWh 份额与分燃料均份额](docs/ai-bi-weekday-evening-mix.png)

公开约定的 catalog / schema 是 `nz_energy.bronze|silver|gold`。个人 workspace 里带邮箱前缀的 catalog 只写未跟踪的 `AGENTS.local.md`。流水线 SQL 与在 workspace 里怎么建，见 `src/pipeline/README.md`。Bundle 合同在根 `databricks.yml` 和 `resources/`。

v1 Gold 粒度：工作日日期 × 节点；晚间均价（TradingPeriod ≥ 35，17:00）对比日间均价（TP 15–34）。排序表是 `nz_energy.gold.evening_spike_ranked`。看板页 `Weekday evening spikes` 用这张排名，外加 Waitaki 节点 `WTK0111` 的按日序列。

发电 Gold 粒度：工作日日期 × EMI `Fuel_Code`；晚间 kWh 份额对比日间份额。表是 `nz_energy.gold.weekday_evening_fuel_mix`。`Hydro` 与 `HYD` 等标签保持 EMI 原样。已核对窗口是 2026-08-03 至 2026-10-30 的工作日（落地的月文件），比价格 90 天窗口更早起算。

### 开发说明

在仓库根目录跑 `databricks bundle validate`，用本机 CLI profile，不要把 workspace URL 写进 git。**不要** `databricks bundle deploy`，除非 YAML 已经 bind 到现有的 pipeline 和 Job；未 bind 就部署可能另起一条 ETL pipeline。计算端仍不拉 EMI。

本仓库的代码与文档在 Cursor 中编写。架构取舍、数据质量规则、以及对外写出的结论，须经本人核对后才算数。Git 提交作者是仓库所有者，不使用 Cursor 的 commit / PR 署名。

这是原创作品集项目，不是 Databricks Academy 课程副本。

### 许可

- 本仓库代码：[MIT](LICENSE)
- EMI 数据集：CC BY 4.0，Electricity Authority（新西兰）
