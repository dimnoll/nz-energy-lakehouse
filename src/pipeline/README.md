# Lakeflow pipeline (SQL)

[English](#english) | [中文](#中文)

One Spark Declarative Pipelines source folder. Free Edition allows one active pipeline of this type, so bronze / silver / gold stay together.

Volume (already uploaded): `/Volumes/nz_energy/bronze/landing`

| File | Writes |
| --- | --- |
| `01_bronze.sql` | `nz_energy.bronze.final_energy_prices_raw`, `network_supply_points_raw` |
| `02_silver.sql` | `nz_energy.silver.prices`, `nsp_current`, `prices_with_location` |
| `03_gold.sql` | `nz_energy.gold.weekday_evening_node_prices`, `evening_spike_ranked` |

Do not add `databricks.yml` here yet. Do not fetch EMI from Databricks compute.

---

## English

### Create schemas

Catalog `nz_energy` already exists. The first pipeline update can create `silver` and `gold` if they are missing. You can also create those two schemas in Catalog Explorer first.

### Link one Git folder, then one pipeline

1. In **Workspace** (your user home), **Create → Git folder** once. Clone this GitHub repo onto `main`. Do **not** clone a second copy inside the pipeline project folder.
2. After a GitHub push: open the Git folder → click the **branch + main** pill to the right of the folder name → **Pull** in the dialog.
3. **New → ETL pipeline** (or **Jobs & Pipelines → Create → ETL pipeline**). Serverless, **triggered**. Default catalog `nz_energy`.
4. **Source code** must be **only** this folder in that Git folder:

   `/Workspace/Users/<you>/nz-energy-lakehouse/src/pipeline/**`

   Remove the editor’s `transformations/**` glob if it is still listed. Pipeline source may contain `CREATE OR REFRESH STREAMING TABLE`, `CREATE OR REFRESH MATERIALIZED VIEW`, and `SET` only — not `DROP`.
5. If `nz_energy.bronze.final_energy_prices_raw` already exists from a SQL-editor run, drop it in **SQL Editor** (left sidebar, a SQL warehouse), **not** in the pipeline:

```sql
DROP TABLE IF EXISTS nz_energy.bronze.final_energy_prices_raw;
```

   Then delete any extra file you added under the pipeline’s `transformations/` folder.

6. **Run** the ETL pipeline once. Then:

```sql
SELECT * FROM nz_energy.gold.evening_spike_ranked ORDER BY spike_rank LIMIT 20;
```

Gold uses **final** files only (`is_interim = false`). Evening is TradingPeriod ≥ 35 (17:00). Daytime baseline is TP 15–34 (07:00–16:30), not overnight.

### Schedule one Job

On the same pipeline page, **Schedule**. Trigger type **Scheduled**, every day 07:00, timezone **Pacific/Auckland**, job name `EMI daily refresh`. Leave Performance optimized off. Do not turn on full refresh on the pipeline task. **Run now** once to confirm the job has a single pipeline task pointing at this pipeline — not a notebook, and not a second ETL pipeline. The job does not download EMI; Volume upload stays manual.

If `databricks fs ls dbfs:/Volumes/nz_energy/bronze/landing` fails, fix the local CLI token before debugging the SQL.

---

## 中文

### 建 schema

catalog `nz_energy` 已有。第一次跑 pipeline 时，若不存在会尝试创建 `silver` / `gold`。也可以先在 Catalog Explorer 里建好。

### 一个 Git folder，一条 pipeline

1. 在 **Workspace** 自己的用户目录 **Create → Git folder**，只克隆一次本仓库的 `main`。不要在 pipeline 工程文件夹里再克隆一份。
2. GitHub 推送之后：打开该 Git folder → 点文件夹名右侧的 **分支 + main** 矩形 → 对话框右上 **Pull**。
3. **New → ETL pipeline**（或 **Jobs & Pipelines → Create → ETL pipeline**）。Serverless、**triggered**。默认 catalog：`nz_energy`。
4. **Source code** 只保留 Git folder 里的本目录：

   `/Workspace/Users/<你>/nz-energy-lakehouse/src/pipeline/**`

   若还挂着编辑器自带的 `transformations/**`，去掉。Pipeline 源只能写 `CREATE OR REFRESH STREAMING TABLE` / `MATERIALIZED VIEW` / `SET`，不能写 `DROP`。
5. 若 SQL 编辑器已经建过 `nz_energy.bronze.final_energy_prices_raw`，在左侧 **SQL Editor**（选一个 SQL warehouse）里删，**不要**写进 pipeline：

```sql
DROP TABLE IF EXISTS nz_energy.bronze.final_energy_prices_raw;
```

   然后删掉 pipeline 的 `transformations/` 下多出来的文件。

6. 再 **Run** 这条 ETL pipeline。再用 SQL 看 Gold。

Gold 只用 final 文件。晚间是 TP ≥ 35（17:00）；日间基线是 TP 15–34（07:00–16:30），不含凌晨。

### 给现有 pipeline 加一个 Job

在同一条 pipeline 页点 **Schedule**。Trigger type **Scheduled**，每天 07:00，时区 **Pacific/Auckland**，Job 名 `EMI daily refresh`。Performance optimized 关掉。不要在 pipeline task 上开 full refresh。再 **Run now** 一次，确认这个 Job 只有一个 pipeline task、指向本 pipeline——不是 notebook，也不是第二条 ETL pipeline。Job 不下载 EMI；Volume 上传仍是人工。
