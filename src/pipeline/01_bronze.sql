-- Bronze: Auto Loader over the UC Volume. Types stay as landed; audit columns are added here.
-- Public volume contract: /Volumes/nz_energy/bronze/landing
-- Pipeline writes use three-part names so this file does not depend on the default schema.

CREATE OR REFRESH STREAMING TABLE nz_energy.bronze.final_energy_prices_raw (
  CONSTRAINT has_trading_date EXPECT (TradingDate IS NOT NULL),
  CONSTRAINT has_poc EXPECT (PointOfConnection IS NOT NULL)
)
COMMENT 'EMI FinalEnergyPrices daily CSV as landed. is_interim is true when the source filename still has _I.'
AS SELECT
  TradingDate,
  TradingPeriod,
  PointOfConnection,
  DollarsPerMegawattHour,
  _metadata.file_path AS _source_file,
  _metadata.file_name AS _source_file_name,
  current_timestamp() AS _ingested_at,
  _metadata.file_name LIKE '%_FinalEnergyPrices_I.csv' AS is_interim
FROM STREAM read_files(
  '/Volumes/nz_energy/bronze/landing/final-energy-prices',
  format => 'csv',
  header => true,
  inferColumnTypes => false
);

CREATE OR REFRESH STREAMING TABLE nz_energy.bronze.network_supply_points_raw (
  CONSTRAINT has_nsp EXPECT (NSP IS NOT NULL)
)
COMMENT 'EMI NetworkSupplyPointsTable snapshot CSV as landed. Later files append; silver keeps the latest snapshot.'
AS SELECT
  *,
  _metadata.file_path AS _source_file,
  _metadata.file_name AS _source_file_name,
  current_timestamp() AS _ingested_at
FROM STREAM read_files(
  '/Volumes/nz_energy/bronze/landing/network-supply-points',
  format => 'csv',
  header => true,
  inferColumnTypes => false
);
