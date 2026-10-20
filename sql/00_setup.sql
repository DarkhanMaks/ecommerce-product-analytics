-- Raw events: October + November, exactly as converted from the CSV files.
-- No cleaning here; cleaning rules are defined and counted in 01_data_quality.sql.
CREATE OR REPLACE VIEW events_raw AS
SELECT *
FROM read_parquet(['data/2019-Oct.parquet', 'data/2019-Nov.parquet']);

-- Cleaned events (built by 01a_build_clean_events.sql). All analysis steps use this view.
-- Remove this block if you need to run 01a_build_clean_events.sql from scratch.
CREATE OR REPLACE VIEW events AS
SELECT * FROM read_parquet('data/events_clean.parquet');

-- Main analysis view: cleaned events WITHOUT the anomalous window 14-17 Nov 2019
-- (purchase events are recorded in uneven blocks there; see docs/data_cleaning_rules.md).
-- Steps 3+ use `events_main`; `events` stays available for the data-quality checks.
CREATE OR REPLACE VIEW events_main AS
SELECT * FROM events
WHERE CAST(event_time AS DATE) NOT BETWEEN DATE '2019-11-14' AND DATE '2019-11-17';
