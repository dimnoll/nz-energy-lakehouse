-- Silver: typed prices, current NSP at POC grain, left join so unmatched grid POCs stay.

CREATE OR REFRESH STREAMING TABLE nz_energy.silver.prices (
  CONSTRAINT valid_trading_date EXPECT (trading_date IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT valid_tp EXPECT (trading_period BETWEEN 1 AND 48) ON VIOLATION DROP ROW,
  CONSTRAINT non_null_poc EXPECT (point_of_connection IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT non_null_price EXPECT (dollars_per_mwh IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT non_negative_price EXPECT (dollars_per_mwh >= 0)
)
COMMENT 'Typed half-hour final energy prices. TP outside 1-48 (DST long days) is dropped in v1. Negative prices are kept and only warned.'
AS SELECT
  to_date(TradingDate) AS trading_date,
  CAST(TradingPeriod AS INT) AS trading_period,
  PointOfConnection AS point_of_connection,
  CAST(DollarsPerMegawattHour AS DOUBLE) AS dollars_per_mwh,
  is_interim,
  _source_file,
  _ingested_at
FROM STREAM nz_energy.bronze.final_energy_prices_raw;

CREATE OR REFRESH MATERIALIZED VIEW nz_energy.silver.nsp_current
COMMENT 'One row per POC from the latest NSP snapshot. Current flag = 1; duplicate POCs keep island/region and a stable NSP code.'
AS
WITH latest_file AS (
  SELECT max(_source_file_name) AS _source_file_name
  FROM nz_energy.bronze.network_supply_points_raw
),
current_rows AS (
  SELECT
    raw.poc_code AS point_of_connection,
    raw.island,
    raw.network_reporting_region,
    CAST(raw.nztm_easting AS DOUBLE) AS nztm_easting,
    CAST(raw.nztm_northing AS DOUBLE) AS nztm_northing,
    raw.description,
    raw.nsp AS nsp_code,
    to_date(raw.start_date) AS start_date,
    raw._source_file
  FROM nz_energy.bronze.network_supply_points_raw raw
  INNER JOIN latest_file
    ON raw._source_file_name = latest_file._source_file_name
  WHERE CAST(raw.current_flag AS INT) = 1
    AND raw.poc_code IS NOT NULL
    AND raw.poc_code <> ''
),
ranked AS (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY point_of_connection
      ORDER BY
        CASE WHEN island IS NOT NULL AND island <> '' THEN 0 ELSE 1 END,
        start_date DESC NULLS LAST,
        nsp_code
    ) AS rn
  FROM current_rows
)
SELECT
  point_of_connection,
  island,
  network_reporting_region,
  nztm_easting,
  nztm_northing,
  description,
  nsp_code,
  start_date,
  _source_file
FROM ranked
WHERE rn = 1;

CREATE OR REFRESH MATERIALIZED VIEW nz_energy.silver.prices_with_location
COMMENT 'Prices left-joined to current NSP. Generation/grid POCs with no NSP row are kept; island is null for those.'
AS SELECT
  p.trading_date,
  p.trading_period,
  p.point_of_connection,
  p.dollars_per_mwh,
  p.is_interim,
  n.island,
  n.network_reporting_region,
  n.nztm_easting,
  n.nztm_northing,
  p._source_file
FROM nz_energy.silver.prices p
LEFT JOIN nz_energy.silver.nsp_current n
  ON p.point_of_connection = n.point_of_connection;
