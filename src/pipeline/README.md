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
2. **New → ETL pipeline** (or **Jobs & Pipelines → Create → ETL pipeline**). Serverless, **triggered**. Default catalog `nz_energy`.
3. **Source code** must be this folder in that Git folder:

   `/Workspace/Users/<you>/nz-energy-lakehouse/src/pipeline/**`

   The empty `transformations/` folder that the editor creates is not the source. Do not paste these `CREATE` statements into a SQL warehouse: that makes a hidden standalone pipeline per table and will collide with this one.
4. If `nz_energy.bronze.final_energy_prices_raw` already exists from a SQL-editor run, drop it first so this pipeline can own it:

```sql
DROP TABLE IF EXISTS nz_energy.bronze.final_energy_prices_raw;
```

5. **Run** once. Then:

```sql
SELECT * FROM nz_energy.gold.evening_spike_ranked ORDER BY spike_rank LIMIT 20;
```

Gold uses **final** files only (`is_interim = false`). Evening is TradingPeriod ≥ 35 (17:00). Daytime baseline is TP 15–34 (07:00–16:30), not overnight.

If `databricks fs ls dbfs:/Volumes/nz_energy/bronze/landing` fails, fix the local CLI token before debugging the SQL.

---

## 中文

### 建 schema

catalog `nz_energy` 已有。第一次跑 pipeline 时，若不存在会尝试创建 `silver` / `gold`。也可以先在 Catalog Explorer 里建好。

### 一个 Git folder，一条 pipeline

1. 在 **Workspace** 自己的用户目录 **Create → Git folder**，只克隆一次本仓库的 `main`。不要在 pipeline 工程文件夹里再克隆一份。
2. **New → ETL pipeline**（或 **Jobs & Pipelines → Create → ETL pipeline**）。Serverless、**triggered**。默认 catalog：`nz_energy`。
3. **Source code** 指向 Git folder 里的本目录：

   `/Workspace/Users/<你>/nz-energy-lakehouse/src/pipeline/**`

   编辑器自带的空 `transformations/` 不是源。不要把这些 `CREATE` 贴进 SQL warehouse 去跑：那样每个表会变成一条隐藏的 standalone pipeline，和这条 ETL pipeline 抢所有权。
4. 若 SQL 编辑器已经建过 `nz_energy.bronze.final_energy_prices_raw`，先删掉再跑这条 pipeline：

```sql
DROP TABLE IF EXISTS nz_energy.bronze.final_energy_prices_raw;
```

5. **Run** 一次。再用 SQL 看 Gold。

Gold 只用 final 文件。晚间是 TP ≥ 35（17:00）；日间基线是 TP 15–34（07:00–16:30），不含凌晨。
