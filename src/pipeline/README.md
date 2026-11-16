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

### Create the pipeline in the workspace

1. **Lakeflow** → **Pipelines** → **Create pipeline**.
2. Name it something like `nz-energy-prices`. Use **serverless**. Leave it **triggered** (not continuous).
3. Default catalog: `nz_energy`. Default schema can be `bronze`; table names in the SQL are fully qualified.
4. Add the three `.sql` files in this folder as the pipeline source (Git folder path `src/pipeline`, or upload the files).
5. **Run** once. Then in a SQL editor:

```sql
SELECT * FROM nz_energy.gold.evening_spike_ranked ORDER BY spike_rank LIMIT 20;
```

Gold uses **final** files only (`is_interim = false`). Evening is TradingPeriod ≥ 35 (17:00). Daytime baseline is TP 15–34 (07:00–16:30), not overnight.

If `databricks fs ls dbfs:/Volumes/nz_energy/bronze/landing` fails, fix the local CLI token before debugging the SQL.

---

## 中文

### 建 schema

catalog `nz_energy` 已有。第一次跑 pipeline 时，若不存在会尝试创建 `silver` / `gold`。也可以先在 Catalog Explorer 里建好。

### 在 workspace 里建这条 pipeline

1. **Lakeflow** → **Pipelines** → **Create pipeline**。
2. 名称例如 `nz-energy-prices`。用 **serverless**，**triggered**（不要 continuous）。
3. 默认 catalog：`nz_energy`。默认 schema 用 `bronze` 即可；SQL 里是三层全名。
4. 把本目录三个 `.sql` 加为源（Git folder 的 `src/pipeline`，或直接上传）。
5. **Run** 一次。再用 SQL 看 Gold。

Gold 只用 final 文件。晚间是 TP ≥ 35（17:00）；日间基线是 TP 15–34（07:00–16:30），不含凌晨。
