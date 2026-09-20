-- =============================================================================
-- GOVERNED VIEWS: Canonical metric definitions
-- =============================================================================
-- These views encode the SINGLE source of truth for each supply chain metric.
-- The semantic view layer will point to these, ensuring every persona
-- (planning, procurement, logistics) gets identical answers.
-- =============================================================================

USE DATABASE SUPPLY_CHAIN_ONTOLOGY;
USE SCHEMA GOVERNED;

-- ─── VIEW 1: ORDER FULFILLMENT FACTS ────────────────────────────────────────
-- Grain: one row per order, with delivery and fulfillment metrics
CREATE OR REPLACE VIEW V_ORDER_FULFILLMENT AS
SELECT
    po.ORDER_ID,
    po.CUSTOMER_ID,
    c.CUSTOMER_NAME,
    c.SEGMENT          AS CUSTOMER_SEGMENT,
    c.REGION           AS CUSTOMER_REGION,
    c.PRIORITY         AS CUSTOMER_PRIORITY,
    po.PLANT_ID,
    p.PLANT_NAME,
    p.PLANT_TYPE,
    p.REGION           AS PLANT_REGION,
    po.ORDER_DATE,
    po.REQUESTED_DATE,
    po.PROMISED_DATE,
    po.ACTUAL_DELIVERY_DATE,
    po.ORDER_STATUS,
    po.TOTAL_AMOUNT,
    po.CURRENCY,
    -- On-Time Delivery: delivered on or before the REQUESTED date
    CASE
        WHEN po.ACTUAL_DELIVERY_DATE IS NOT NULL
             AND po.ACTUAL_DELIVERY_DATE <= po.REQUESTED_DATE
        THEN 1 ELSE 0
    END AS IS_ON_TIME,
    -- Days late (negative = early)
    CASE
        WHEN po.ACTUAL_DELIVERY_DATE IS NOT NULL
        THEN DATEDIFF('day', po.REQUESTED_DATE, po.ACTUAL_DELIVERY_DATE)
        ELSE NULL
    END AS DAYS_LATE,
    -- Order line aggregates
    ol.TOTAL_QTY_ORDERED,
    ol.TOTAL_QTY_FULFILLED,
    -- Fill Rate per order: qty fulfilled / qty ordered
    CASE
        WHEN ol.TOTAL_QTY_ORDERED > 0
        THEN ROUND(ol.TOTAL_QTY_FULFILLED::DECIMAL / ol.TOTAL_QTY_ORDERED * 100, 2)
        ELSE NULL
    END AS ORDER_FILL_RATE_PCT
FROM SUPPLY_CHAIN_ONTOLOGY.RAW.PURCHASE_ORDER po
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.CUSTOMER c ON po.CUSTOMER_ID = c.CUSTOMER_ID
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PLANT p ON po.PLANT_ID = p.PLANT_ID
LEFT JOIN (
    SELECT
        ORDER_ID,
        SUM(QUANTITY_ORDERED)   AS TOTAL_QTY_ORDERED,
        SUM(COALESCE(QUANTITY_FULFILLED, 0)) AS TOTAL_QTY_FULFILLED
    FROM SUPPLY_CHAIN_ONTOLOGY.RAW.ORDER_LINE
    GROUP BY ORDER_ID
) ol ON po.ORDER_ID = ol.ORDER_ID;

-- ─── VIEW 2: SHIPMENT COST FACTS (for Landed Cost) ─────────────────────────
-- Grain: one row per shipment with full landed cost breakdown
CREATE OR REPLACE VIEW V_SHIPMENT_COSTS AS
SELECT
    s.SHIPMENT_ID,
    s.ORDER_ID,
    po.CUSTOMER_ID,
    c.CUSTOMER_NAME,
    c.REGION            AS CUSTOMER_REGION,
    s.PLANT_ID,
    p.PLANT_NAME,
    p.REGION            AS PLANT_REGION,
    s.CARRIER,
    s.TRANSPORT_MODE,
    s.SHIP_DATE,
    s.EXPECTED_ARRIVAL,
    s.ACTUAL_ARRIVAL,
    s.SHIPMENT_STATUS,
    po.TOTAL_AMOUNT     AS ORDER_VALUE,
    s.FREIGHT_COST,
    s.CUSTOMS_COST,
    s.INSURANCE_COST,
    -- Landed Cost = product cost + freight + customs + insurance
    (po.TOTAL_AMOUNT + s.FREIGHT_COST + s.CUSTOMS_COST + s.INSURANCE_COST)
        AS TOTAL_LANDED_COST,
    -- Logistics cost as % of order value
    CASE
        WHEN po.TOTAL_AMOUNT > 0
        THEN ROUND((s.FREIGHT_COST + s.CUSTOMS_COST + s.INSURANCE_COST)::DECIMAL
                    / po.TOTAL_AMOUNT * 100, 2)
        ELSE NULL
    END AS LOGISTICS_COST_PCT,
    -- Shipment on-time?
    CASE
        WHEN s.ACTUAL_ARRIVAL IS NOT NULL
             AND s.ACTUAL_ARRIVAL <= s.EXPECTED_ARRIVAL
        THEN 1 ELSE 0
    END AS SHIPMENT_ON_TIME,
    CASE
        WHEN s.ACTUAL_ARRIVAL IS NOT NULL
        THEN DATEDIFF('day', s.EXPECTED_ARRIVAL, s.ACTUAL_ARRIVAL)
        ELSE NULL
    END AS SHIPMENT_DAYS_LATE
FROM SUPPLY_CHAIN_ONTOLOGY.RAW.SHIPMENT s
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PURCHASE_ORDER po ON s.ORDER_ID = po.ORDER_ID
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.CUSTOMER c ON po.CUSTOMER_ID = c.CUSTOMER_ID
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PLANT p ON s.PLANT_ID = p.PLANT_ID;

-- ─── VIEW 3: INVENTORY METRICS (for Days of Inventory) ──────────────────────
-- Grain: one row per part × plant × snapshot date
CREATE OR REPLACE VIEW V_INVENTORY_METRICS AS
SELECT
    i.INVENTORY_ID,
    i.PART_ID,
    pt.PART_NAME,
    pt.CATEGORY         AS PART_CATEGORY,
    pt.IS_CRITICAL,
    pt.UNIT_COST,
    i.PLANT_ID,
    pl.PLANT_NAME,
    pl.REGION            AS PLANT_REGION,
    i.SNAPSHOT_DATE,
    i.QUANTITY_ON_HAND,
    i.QUANTITY_RESERVED,
    i.QUANTITY_IN_TRANSIT,
    (i.QUANTITY_ON_HAND - i.QUANTITY_RESERVED)  AS AVAILABLE_STOCK,
    i.REORDER_POINT,
    i.SAFETY_STOCK,
    -- Below reorder point?
    CASE
        WHEN (i.QUANTITY_ON_HAND - i.QUANTITY_RESERVED) < i.REORDER_POINT
        THEN TRUE ELSE FALSE
    END AS BELOW_REORDER,
    -- Below safety stock?
    CASE
        WHEN (i.QUANTITY_ON_HAND - i.QUANTITY_RESERVED) < i.SAFETY_STOCK
        THEN TRUE ELSE FALSE
    END AS BELOW_SAFETY_STOCK,
    -- Inventory value
    (i.QUANTITY_ON_HAND * pt.UNIT_COST) AS INVENTORY_VALUE,
    -- Average daily demand (computed from order lines in the same month)
    demand.AVG_DAILY_DEMAND,
    -- Days of Inventory = on-hand / avg daily demand
    CASE
        WHEN demand.AVG_DAILY_DEMAND > 0
        THEN ROUND(i.QUANTITY_ON_HAND::DECIMAL / demand.AVG_DAILY_DEMAND, 1)
        ELSE NULL
    END AS DAYS_OF_INVENTORY
FROM SUPPLY_CHAIN_ONTOLOGY.RAW.INVENTORY i
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PART pt ON i.PART_ID = pt.PART_ID
JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PLANT pl ON i.PLANT_ID = pl.PLANT_ID
LEFT JOIN (
    -- Average daily demand per part per plant per month
    SELECT
        ol.PART_ID,
        po.PLANT_ID,
        DATE_TRUNC('month', po.ORDER_DATE) AS ORDER_MONTH,
        ROUND(SUM(ol.QUANTITY_ORDERED)::DECIMAL
              / GREATEST(DATEDIFF('day',
                    DATE_TRUNC('month', po.ORDER_DATE),
                    LAST_DAY(po.ORDER_DATE, 'month')) + 1, 1), 2)
            AS AVG_DAILY_DEMAND
    FROM SUPPLY_CHAIN_ONTOLOGY.RAW.ORDER_LINE ol
    JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PURCHASE_ORDER po ON ol.ORDER_ID = po.ORDER_ID
    GROUP BY ol.PART_ID, po.PLANT_ID, DATE_TRUNC('month', po.ORDER_DATE)
) demand
  ON i.PART_ID = demand.PART_ID
  AND i.PLANT_ID = demand.PLANT_ID
  AND DATE_TRUNC('month', i.SNAPSHOT_DATE) = demand.ORDER_MONTH;

-- ─── VIEW 4: SUPPLIER PERFORMANCE ───────────────────────────────────────────
-- Grain: one row per supplier with aggregated performance metrics
CREATE OR REPLACE VIEW V_SUPPLIER_PERFORMANCE AS
SELECT
    s.SUPPLIER_ID,
    s.SUPPLIER_NAME,
    s.COUNTRY            AS SUPPLIER_COUNTRY,
    s.REGION             AS SUPPLIER_REGION,
    s.TIER               AS SUPPLIER_TIER,
    s.RELIABILITY_SCORE,
    s.LEAD_TIME_DAYS     AS STATED_LEAD_TIME_DAYS,
    s.CERTIFIED,
    COUNT(DISTINCT pt.PART_ID)   AS PARTS_SUPPLIED,
    COUNT(DISTINCT spp.PLANT_ID) AS PLANTS_SERVED,
    AVG(spp.CONTRACT_PRICE)      AS AVG_CONTRACT_PRICE,
    -- Categories served
    LISTAGG(DISTINCT pt.CATEGORY, ', ') WITHIN GROUP (ORDER BY pt.CATEGORY)
        AS CATEGORIES_SERVED
FROM SUPPLY_CHAIN_ONTOLOGY.RAW.SUPPLIER s
LEFT JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.PART pt ON s.SUPPLIER_ID = pt.SUPPLIER_ID
LEFT JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.SUPPLIER_PART_PLANT spp ON s.SUPPLIER_ID = spp.SUPPLIER_ID
GROUP BY s.SUPPLIER_ID, s.SUPPLIER_NAME, s.COUNTRY, s.REGION,
         s.TIER, s.RELIABILITY_SCORE, s.LEAD_TIME_DAYS, s.CERTIFIED;

-- ─── VIEW 5: CROSS-DOMAIN SUMMARY (the "one question, one answer" view) ────
-- Combines all canonical metrics for executive/cross-persona queries
CREATE OR REPLACE VIEW V_SUPPLY_CHAIN_SUMMARY AS
SELECT
    -- Time grain
    DATE_TRUNC('month', po.ORDER_DATE) AS MONTH,

    -- On-Time Delivery Rate (canonical definition)
    ROUND(
        SUM(CASE WHEN po.ACTUAL_DELIVERY_DATE IS NOT NULL
                      AND po.ACTUAL_DELIVERY_DATE <= po.REQUESTED_DATE
                 THEN 1 ELSE 0 END)::DECIMAL
        / NULLIF(SUM(CASE WHEN po.ACTUAL_DELIVERY_DATE IS NOT NULL THEN 1 ELSE 0 END), 0)
        * 100, 2
    ) AS ON_TIME_DELIVERY_RATE_PCT,

    -- Fill Rate (canonical definition)
    ROUND(
        SUM(ol.TOTAL_QTY_FULFILLED)::DECIMAL
        / NULLIF(SUM(ol.TOTAL_QTY_ORDERED), 0) * 100, 2
    ) AS FILL_RATE_PCT,

    -- Average Landed Cost per order
    ROUND(
        AVG(po.TOTAL_AMOUNT + COALESCE(sh.FREIGHT_COST, 0)
            + COALESCE(sh.CUSTOMS_COST, 0) + COALESCE(sh.INSURANCE_COST, 0)), 2
    ) AS AVG_LANDED_COST,

    -- Total logistics cost
    SUM(COALESCE(sh.FREIGHT_COST, 0) + COALESCE(sh.CUSTOMS_COST, 0)
        + COALESCE(sh.INSURANCE_COST, 0)) AS TOTAL_LOGISTICS_COST,

    -- Order counts
    COUNT(DISTINCT po.ORDER_ID) AS TOTAL_ORDERS,
    SUM(po.TOTAL_AMOUNT)        AS TOTAL_ORDER_VALUE

FROM SUPPLY_CHAIN_ONTOLOGY.RAW.PURCHASE_ORDER po
LEFT JOIN (
    SELECT ORDER_ID,
           SUM(QUANTITY_ORDERED)                      AS TOTAL_QTY_ORDERED,
           SUM(COALESCE(QUANTITY_FULFILLED, 0))       AS TOTAL_QTY_FULFILLED
    FROM SUPPLY_CHAIN_ONTOLOGY.RAW.ORDER_LINE
    GROUP BY ORDER_ID
) ol ON po.ORDER_ID = ol.ORDER_ID
LEFT JOIN SUPPLY_CHAIN_ONTOLOGY.RAW.SHIPMENT sh ON po.ORDER_ID = sh.ORDER_ID
GROUP BY DATE_TRUNC('month', po.ORDER_DATE)
ORDER BY MONTH;
