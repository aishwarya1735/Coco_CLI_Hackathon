-- PIPELINE SETUP: Near-Real-Time Data Pipeline
-- Task + Stream + Dynamic Tables

USE DATABASE SUPPLY_CHAIN_HUB;
CREATE SCHEMA IF NOT EXISTS PIPELINE;

CREATE OR REPLACE TABLE PIPELINE.RAW_SHIPMENT_EVENTS_LANDING (
    shipment_event_id TEXT, shipment_id TEXT, event_timestamp TIMESTAMP_NTZ,
    event_type TEXT, location_latitude NUMBER(8,4), location_longitude NUMBER(9,4),
    event_description TEXT, ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE STREAM PIPELINE.SHIPMENT_EVENTS_STREAM
  ON TABLE PIPELINE.RAW_SHIPMENT_EVENTS_LANDING APPEND_ONLY = TRUE;

CREATE OR REPLACE TASK PIPELINE.GENERATE_SHIPMENT_EVENTS
  WAREHOUSE = COMPUTE_WH SCHEDULE = '5 MINUTE'
AS
INSERT INTO PIPELINE.RAW_SHIPMENT_EVENTS_LANDING
    (shipment_event_id, shipment_id, event_timestamp, event_type,
     location_latitude, location_longitude, event_description)
SELECT
    'EVT-RT-' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS') || '-' || SEQ4(),
    s.SHIPMENT_ID,
    DATEADD(MINUTE, -UNIFORM(0, 5, RANDOM()), CURRENT_TIMESTAMP()),
    event_types.event_type,
    ROUND(UNIFORM(-40, 60, RANDOM())::FLOAT + RANDOM() / 1e18, 4),
    ROUND(UNIFORM(-180, 180, RANDOM())::FLOAT + RANDOM() / 1e18, 4),
    event_types.description
FROM (SELECT SHIPMENT_ID FROM RAW.SHIPMENTS WHERE SHIPMENT_STATUS IN ('IN_TRANSIT','PLANNED') ORDER BY RANDOM() LIMIT 10) s
CROSS JOIN (
    SELECT column1 AS event_type, column2 AS description FROM VALUES
    ('IN_TRANSIT', 'Vehicle in transit - GPS ping'),
    ('CUSTOMS', 'Arrived at customs checkpoint'),
    ('DELIVERED', 'Package delivered to destination'),
    ('DELAYED', 'Shipment delayed due to weather'),
    ('EXCEPTION', 'Route deviation detected')
) event_types
WHERE RANDOM() > 0.6;

CREATE OR REPLACE DYNAMIC TABLE PIPELINE.EVENT_SUMMARY_HOURLY
  WAREHOUSE = COMPUTE_WH TARGET_LAG = '5 minutes'
AS
SELECT DATE_TRUNC('HOUR', event_timestamp) AS event_hour, event_type,
  COUNT(*) AS event_count, COUNT(DISTINCT shipment_id) AS unique_shipments,
  MAX(ingested_at) AS last_ingested
FROM PIPELINE.RAW_SHIPMENT_EVENTS_LANDING
GROUP BY event_hour, event_type;

CREATE OR REPLACE DYNAMIC TABLE PIPELINE.DELIVERY_ALERTS
  WAREHOUSE = COMPUTE_WH TARGET_LAG = '5 minutes'
AS
SELECT e.shipment_id, e.event_type AS alert_type, e.event_timestamp AS alert_time,
  e.event_description AS alert_detail, s.CARRIER_ID, c.CARRIER_NAME,
  s.SHIPMENT_STATUS, s.PLANNED_DELIVERY_AT,
  DATEDIFF(HOUR, s.PLANNED_DELIVERY_AT, e.event_timestamp) AS hours_past_planned
FROM PIPELINE.RAW_SHIPMENT_EVENTS_LANDING e
JOIN RAW.SHIPMENTS s ON e.shipment_id = s.SHIPMENT_ID
LEFT JOIN RAW.CARRIERS c ON s.CARRIER_ID = c.CARRIER_ID
WHERE e.event_type IN ('DELAYED', 'EXCEPTION');

CREATE OR REPLACE DYNAMIC TABLE PIPELINE.CARRIER_REALTIME_METRICS
  WAREHOUSE = COMPUTE_WH TARGET_LAG = '5 minutes'
AS
SELECT c.CARRIER_NAME, c.SERVICE_LEVEL, COUNT(*) AS total_events,
  SUM(CASE WHEN e.event_type = 'DELIVERED' THEN 1 ELSE 0 END) AS deliveries,
  SUM(CASE WHEN e.event_type = 'DELAYED' THEN 1 ELSE 0 END) AS delays,
  SUM(CASE WHEN e.event_type = 'EXCEPTION' THEN 1 ELSE 0 END) AS exceptions,
  ROUND(100.0 * SUM(CASE WHEN e.event_type = 'DELAYED' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS delay_rate_pct,
  MAX(e.event_timestamp) AS latest_event
FROM PIPELINE.RAW_SHIPMENT_EVENTS_LANDING e
JOIN RAW.SHIPMENTS s ON e.shipment_id = s.SHIPMENT_ID
JOIN RAW.CARRIERS c ON s.CARRIER_ID = c.CARRIER_ID
GROUP BY c.CARRIER_NAME, c.SERVICE_LEVEL;

-- Resume task: ALTER TASK PIPELINE.GENERATE_SHIPMENT_EVENTS RESUME;
-- Suspend task: ALTER TASK PIPELINE.GENERATE_SHIPMENT_EVENTS SUSPEND;
