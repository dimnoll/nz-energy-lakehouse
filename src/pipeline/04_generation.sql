-- Generation mix: same pipeline as prices, separate Gold grain.
-- EMI Generation_MD is monthly, wide (TP1-TP50, kWh). Do not fold Fuel_Code into evening_spike_ranked.
-- Hydro vs HYD (and Wind vs WIN) are distinct EMI labels; v1 does not remap them.

CREATE OR REFRESH STREAMING TABLE nz_energy.bronze.generation_md_raw (
  CONSTRAINT has_trading_date EXPECT (trading_date IS NOT NULL),
  CONSTRAINT has_poc EXPECT (poc_code IS NOT NULL)
)
COMMENT 'EMI Generation_MD monthly CSV as landed. Trading_Date and TP1-TP50 keep source names except snake_case dimensions.'
AS SELECT
  Site_Code AS site_code,
  POC_Code AS poc_code,
  Nwk_Code AS nwk_code,
  Gen_Code AS gen_code,
  Fuel_Code AS fuel_code,
  Tech_Code AS tech_code,
  Trading_Date AS trading_date,
  TP1, TP2, TP3, TP4, TP5, TP6, TP7, TP8, TP9, TP10,
  TP11, TP12, TP13, TP14, TP15, TP16, TP17, TP18, TP19, TP20,
  TP21, TP22, TP23, TP24, TP25, TP26, TP27, TP28, TP29, TP30,
  TP31, TP32, TP33, TP34, TP35, TP36, TP37, TP38, TP39, TP40,
  TP41, TP42, TP43, TP44, TP45, TP46, TP47, TP48, TP49, TP50,
  _metadata.file_path AS _source_file,
  _metadata.file_name AS _source_file_name,
  current_timestamp() AS _ingested_at
FROM STREAM read_files(
  '/Volumes/nz_energy/bronze/landing/generation-md',
  format => 'csv',
  header => true,
  inferColumnTypes => false
);

CREATE OR REFRESH STREAMING TABLE nz_energy.silver.generation_periods (
  CONSTRAINT valid_trading_date EXPECT (trading_date IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT valid_tp EXPECT (trading_period BETWEEN 1 AND 48) ON VIOLATION DROP ROW,
  CONSTRAINT non_null_poc EXPECT (point_of_connection IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT non_null_fuel EXPECT (fuel_code IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT non_null_kwh EXPECT (generation_kwh IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT non_negative_kwh EXPECT (generation_kwh >= 0)
)
COMMENT 'Generation_MD unpivoted to POC x date x trading period x fuel. TP 49-50 (DST long days) dropped like prices. Units are kWh.'
AS SELECT
  to_date(trading_date) AS trading_date,
  CAST(regexp_replace(tp_label, '^TP', '') AS INT) AS trading_period,
  poc_code AS point_of_connection,
  site_code,
  nwk_code,
  gen_code,
  fuel_code,
  tech_code,
  try_cast(generation_kwh_raw AS DOUBLE) AS generation_kwh,
  _source_file,
  _ingested_at
FROM (
  SELECT
    site_code,
    poc_code,
    nwk_code,
    gen_code,
    fuel_code,
    tech_code,
    trading_date,
    TP1, TP2, TP3, TP4, TP5, TP6, TP7, TP8, TP9, TP10,
    TP11, TP12, TP13, TP14, TP15, TP16, TP17, TP18, TP19, TP20,
    TP21, TP22, TP23, TP24, TP25, TP26, TP27, TP28, TP29, TP30,
    TP31, TP32, TP33, TP34, TP35, TP36, TP37, TP38, TP39, TP40,
    TP41, TP42, TP43, TP44, TP45, TP46, TP47, TP48, TP49, TP50,
    _source_file,
    _ingested_at
  FROM STREAM nz_energy.bronze.generation_md_raw
) UNPIVOT (
  generation_kwh_raw FOR tp_label IN (
    TP1, TP2, TP3, TP4, TP5, TP6, TP7, TP8, TP9, TP10,
    TP11, TP12, TP13, TP14, TP15, TP16, TP17, TP18, TP19, TP20,
    TP21, TP22, TP23, TP24, TP25, TP26, TP27, TP28, TP29, TP30,
    TP31, TP32, TP33, TP34, TP35, TP36, TP37, TP38, TP39, TP40,
    TP41, TP42, TP43, TP44, TP45, TP46, TP47, TP48, TP49, TP50
  )
);

CREATE OR REFRESH MATERIALIZED VIEW nz_energy.gold.weekday_evening_fuel_mix
COMMENT 'Grain: weekday date x EMI Fuel_Code. Evening kWh share (TP 35-48) versus daytime (TP 15-34). National mix; not joined to node price ranks. Review before treating as an insight.'
AS
WITH windowed AS (
  SELECT
    trading_date,
    fuel_code,
    sum(CASE WHEN trading_period BETWEEN 15 AND 34 THEN generation_kwh END) AS daytime_kwh,
    sum(CASE WHEN trading_period >= 35 THEN generation_kwh END) AS evening_kwh
  FROM nz_energy.silver.generation_periods
  WHERE weekday(trading_date) BETWEEN 0 AND 4
    AND (trading_period BETWEEN 15 AND 34 OR trading_period >= 35)
  GROUP BY
    trading_date,
    fuel_code
),
totals AS (
  SELECT
    trading_date,
    sum(daytime_kwh) AS daytime_total_kwh,
    sum(evening_kwh) AS evening_total_kwh
  FROM windowed
  GROUP BY trading_date
)
SELECT
  w.trading_date,
  w.fuel_code,
  w.daytime_kwh,
  w.evening_kwh,
  t.daytime_total_kwh,
  t.evening_total_kwh,
  w.daytime_kwh / nullif(t.daytime_total_kwh, 0) AS daytime_share,
  w.evening_kwh / nullif(t.evening_total_kwh, 0) AS evening_share
FROM windowed w
INNER JOIN totals t
  ON w.trading_date = t.trading_date
WHERE w.daytime_kwh IS NOT NULL
  AND w.evening_kwh IS NOT NULL;
