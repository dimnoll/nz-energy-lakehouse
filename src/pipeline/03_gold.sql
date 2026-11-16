-- Gold: weekday evening peak versus daytime, for the locked v1 question only.
-- TradingPeriod 1 starts at 00:00 NZ time; TP 35 is 17:00.
-- Daytime baseline is TP 15-34 (07:00-16:30), not overnight TP 1-14.
-- Spark weekday(): 0 = Monday ... 6 = Sunday.

CREATE OR REFRESH MATERIALIZED VIEW nz_energy.gold.weekday_evening_node_prices
COMMENT 'Grain: weekday date x node. Evening mean (TP 35-48) versus daytime mean (TP 15-34). Interim source files excluded.'
AS
WITH per_day AS (
  SELECT
    trading_date,
    point_of_connection,
    max(island) AS island,
    max(network_reporting_region) AS network_reporting_region,
    avg(CASE WHEN trading_period BETWEEN 15 AND 34 THEN dollars_per_mwh END) AS daytime_avg_dollars_per_mwh,
    avg(CASE WHEN trading_period >= 35 THEN dollars_per_mwh END) AS evening_avg_dollars_per_mwh,
    count(CASE WHEN trading_period BETWEEN 15 AND 34 THEN 1 END) AS daytime_period_count,
    count(CASE WHEN trading_period >= 35 THEN 1 END) AS evening_period_count
  FROM nz_energy.silver.prices_with_location
  WHERE NOT is_interim
    AND weekday(trading_date) BETWEEN 0 AND 4
    AND (trading_period BETWEEN 15 AND 34 OR trading_period >= 35)
  GROUP BY
    trading_date,
    point_of_connection
)
SELECT
  trading_date,
  point_of_connection,
  island,
  network_reporting_region,
  daytime_avg_dollars_per_mwh,
  evening_avg_dollars_per_mwh,
  evening_avg_dollars_per_mwh / nullif(daytime_avg_dollars_per_mwh, 0) AS evening_to_daytime_ratio,
  daytime_period_count,
  evening_period_count
FROM per_day
WHERE daytime_avg_dollars_per_mwh IS NOT NULL
  AND evening_avg_dollars_per_mwh IS NOT NULL;

CREATE OR REFRESH MATERIALIZED VIEW nz_energy.gold.evening_spike_ranked
COMMENT 'Nodes ranked by mean weekday evening-to-daytime ratio across the landed window. Review before treating as an insight.'
AS
SELECT
  dense_rank() OVER (ORDER BY mean_evening_to_daytime_ratio DESC) AS spike_rank,
  point_of_connection,
  island,
  network_reporting_region,
  mean_daytime_dollars_per_mwh,
  mean_evening_dollars_per_mwh,
  mean_evening_to_daytime_ratio,
  weekday_days
FROM (
  SELECT
    point_of_connection,
    max(island) AS island,
    max(network_reporting_region) AS network_reporting_region,
    avg(daytime_avg_dollars_per_mwh) AS mean_daytime_dollars_per_mwh,
    avg(evening_avg_dollars_per_mwh) AS mean_evening_dollars_per_mwh,
    avg(evening_to_daytime_ratio) AS mean_evening_to_daytime_ratio,
    count(*) AS weekday_days
  FROM nz_energy.gold.weekday_evening_node_prices
  GROUP BY point_of_connection
);
