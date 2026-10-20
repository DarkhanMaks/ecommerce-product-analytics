-- Raw events: October + November, exactly as converted from the CSV files.
-- No cleaning here; cleaning rules are defined and counted in 01_data_quality.sql.
CREATE OR REPLACE VIEW events_raw AS
SELECT *
FROM read_parquet(['data/2019-Oct.parquet', 'data/2019-Nov.parquet']);

-- Cleaned events (built by 01a_build_clean_events.sql). All analysis steps use this view.
-- Remove this block if you need to run 01a_build_clean_events.sql from scratch.
CREATE OR REPLACE VIEW events AS
SELECT * FROM read_parquet('data/events_clean.parquet');
