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
  CONSTRAINT has_nsp EXPECT (nsp IS NOT NULL)
)
COMMENT 'EMI NetworkSupplyPointsTable snapshot as landed. Header spaces are aliased; Delta rejects those characters without column mapping.'
AS SELECT
  `Current flag` AS current_flag,
  NSP AS nsp,
  `NSP replaced by` AS nsp_replaced_by,
  `POC code` AS poc_code,
  `Network participant` AS network_participant,
  `Embedded under POC code` AS embedded_under_poc_code,
  `Embedded under network participant` AS embedded_under_network_participant,
  `Reconciliation type` AS reconciliation_type,
  `X flow` AS x_flow,
  `I flow` AS i_flow,
  Description AS description,
  `NZTM easting` AS nztm_easting,
  `NZTM northing` AS nztm_northing,
  `Network reporting region ID` AS network_reporting_region_id,
  `Network reporting region` AS network_reporting_region,
  Zone AS zone,
  Island AS island,
  `Start date` AS start_date,
  `Start TP` AS start_tp,
  `End date` AS end_date,
  `End TP` AS end_tp,
  `SB ICP` AS sb_icp,
  `Balancing code` AS balancing_code,
  MEP AS mep,
  `Responsible participant` AS responsible_participant,
  `Certification expiry` AS certification_expiry,
  `Metering information exemption expiry date` AS metering_information_exemption_expiry_date,
  _metadata.file_path AS _source_file,
  _metadata.file_name AS _source_file_name,
  current_timestamp() AS _ingested_at
FROM STREAM read_files(
  '/Volumes/nz_energy/bronze/landing/network-supply-points',
  format => 'csv',
  header => true,
  inferColumnTypes => false
);
