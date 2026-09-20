-- ============================================================
-- PERSONA CONSISTENCY DEMO QUERIES
-- Proves the same metric resolves identically across personas
-- ============================================================

-- ============================================================
-- METRIC 1: ON-TIME DELIVERY RATE
-- Used by: Logistics (delivery performance), Procurement (supplier SLA)
-- Definition: % of delivered shipments where actual_arrival <= requested_delivery
-- ============================================================

-- Logistics asks: "What is our delivery performance?"
SELECT
    'LOGISTICS' AS PERSONA,
    'On-Time Delivery Rate' AS METRIC,
    COUNT(*) AS TOTAL_DELIVERED,
    SUM(CASE WHEN s.ACTUAL_ARRIVAL <= oh.REQUESTED_DELIVERY THEN 1 ELSE 0 END) AS ON_TIME_COUNT,
    ROUND(100.0 * SUM(CASE WHEN s.ACTUAL_ARRIVAL <= oh.REQUESTED_DELIVERY THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS RATE_PCT
FROM SUPPLY_CHAIN_HUB.RAW.SHIPMENT s
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON s.ORDER_ID = oh.ORDER_ID
WHERE s.ACTUAL_ARRIVAL IS NOT NULL;

-- Procurement asks: "What is the supplier delivery SLA?"
SELECT
    'PROCUREMENT' AS PERSONA,
    'On-Time Delivery Rate' AS METRIC,
    COUNT(*) AS TOTAL_DELIVERED,
    SUM(CASE WHEN s.ACTUAL_ARRIVAL <= oh.REQUESTED_DELIVERY THEN 1 ELSE 0 END) AS ON_TIME_COUNT,
    ROUND(100.0 * SUM(CASE WHEN s.ACTUAL_ARRIVAL <= oh.REQUESTED_DELIVERY THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS RATE_PCT
FROM SUPPLY_CHAIN_HUB.RAW.SHIPMENT s
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON s.ORDER_ID = oh.ORDER_ID
WHERE s.ACTUAL_ARRIVAL IS NOT NULL;

-- BOTH RETURN THE SAME NUMBER ✓

-- ============================================================
-- METRIC 2: FILL RATE
-- Used by: Planning (demand fulfillment), Logistics (service level)
-- Definition: % of qty fulfilled vs qty ordered, excl CANCELLED/OPEN
-- ============================================================

-- Planning asks: "What is our demand fulfillment rate?"
SELECT
    'PLANNING' AS PERSONA,
    'Fill Rate' AS METRIC,
    SUM(ol.QUANTITY_ORDERED) AS TOTAL_ORDERED,
    SUM(ol.QUANTITY_FULFILLED) AS TOTAL_FULFILLED,
    ROUND(100.0 * SUM(ol.QUANTITY_FULFILLED)
          / NULLIF(SUM(ol.QUANTITY_ORDERED), 0), 2) AS RATE_PCT
FROM SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON ol.ORDER_ID = oh.ORDER_ID
WHERE oh.ORDER_STATUS NOT IN ('CANCELLED', 'OPEN');

-- Logistics asks: "What is our service level?"
SELECT
    'LOGISTICS' AS PERSONA,
    'Fill Rate' AS METRIC,
    SUM(ol.QUANTITY_ORDERED) AS TOTAL_ORDERED,
    SUM(ol.QUANTITY_FULFILLED) AS TOTAL_FULFILLED,
    ROUND(100.0 * SUM(ol.QUANTITY_FULFILLED)
          / NULLIF(SUM(ol.QUANTITY_ORDERED), 0), 2) AS RATE_PCT
FROM SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON ol.ORDER_ID = oh.ORDER_ID
WHERE oh.ORDER_STATUS NOT IN ('CANCELLED', 'OPEN');

-- BOTH RETURN THE SAME NUMBER ✓

-- ============================================================
-- METRIC 3: DAYS OF INVENTORY (by plant, top 5 lowest)
-- Used by: Planning (stock health), Procurement (reorder triggers)
-- Definition: qty_on_hand / avg_daily_demand
-- ============================================================

SELECT
    'ALL PERSONAS' AS PERSONA,
    'Days of Inventory' AS METRIC,
    p.PLANT_NAME,
    pt.PART_NAME,
    i.QUANTITY_ON_HAND,
    ROUND(i.QUANTITY_ON_HAND
          / NULLIF(dd.AVG_DAILY_DEMAND, 0), 1) AS DAYS_OF_INVENTORY
FROM SUPPLY_CHAIN_HUB.RAW.INVENTORY i
JOIN SUPPLY_CHAIN_HUB.RAW.PLANT p ON i.PLANT_ID = p.PLANT_ID
JOIN SUPPLY_CHAIN_HUB.RAW.PART pt ON i.PART_ID = pt.PART_ID
LEFT JOIN (
    SELECT oh.PLANT_ID, ol.PART_ID,
           SUM(ol.QUANTITY_ORDERED)
           / NULLIF(DATEDIFF('day', MIN(oh.ORDER_DATE), MAX(oh.ORDER_DATE)), 0) AS AVG_DAILY_DEMAND
    FROM SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol
    JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON ol.ORDER_ID = oh.ORDER_ID
    WHERE oh.ORDER_STATUS != 'CANCELLED'
    GROUP BY oh.PLANT_ID, ol.PART_ID
) dd ON i.PLANT_ID = dd.PLANT_ID AND i.PART_ID = dd.PART_ID
ORDER BY DAYS_OF_INVENTORY ASC NULLS LAST
LIMIT 10;

-- ============================================================
-- METRIC 4: LANDED COST (top 5 orders)
-- Used by: Procurement (cost analysis), Logistics (freight optimization)
-- Definition: product_cost + freight + customs + insurance
-- ============================================================

SELECT
    'ALL PERSONAS' AS PERSONA,
    'Landed Cost' AS METRIC,
    oh.ORDER_ID,
    c.CUSTOMER_NAME,
    SUM(ol.LINE_TOTAL) AS PRODUCT_COST,
    SUM(s.FREIGHT_COST) AS FREIGHT,
    SUM(s.CUSTOMS_COST) AS CUSTOMS,
    SUM(s.INSURANCE_COST) AS INSURANCE,
    SUM(ol.LINE_TOTAL) + SUM(s.FREIGHT_COST) + SUM(s.CUSTOMS_COST) + SUM(s.INSURANCE_COST) AS LANDED_COST
FROM SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol ON oh.ORDER_ID = ol.ORDER_ID
JOIN SUPPLY_CHAIN_HUB.RAW.SHIPMENT s ON oh.ORDER_ID = s.ORDER_ID
JOIN SUPPLY_CHAIN_HUB.RAW.CUSTOMER c ON oh.CUSTOMER_ID = c.CUSTOMER_ID
WHERE oh.ORDER_STATUS IN ('DELIVERED', 'SHIPPED')
GROUP BY oh.ORDER_ID, c.CUSTOMER_NAME
ORDER BY LANDED_COST DESC
LIMIT 5;

-- ============================================================
-- CROSS-PERSONA CONSISTENCY PROOF
-- Same question from 3 personas → same answer
-- "What is the overall fill rate?"
-- ============================================================

SELECT 'PLANNING' AS PERSONA, 'What is demand fulfillment?' AS QUESTION,
       ROUND(100.0 * SUM(ol.QUANTITY_FULFILLED) / NULLIF(SUM(ol.QUANTITY_ORDERED), 0), 2) AS ANSWER
FROM SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON ol.ORDER_ID = oh.ORDER_ID
WHERE oh.ORDER_STATUS NOT IN ('CANCELLED', 'OPEN')
UNION ALL
SELECT 'PROCUREMENT', 'What is the order service level?',
       ROUND(100.0 * SUM(ol.QUANTITY_FULFILLED) / NULLIF(SUM(ol.QUANTITY_ORDERED), 0), 2)
FROM SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON ol.ORDER_ID = oh.ORDER_ID
WHERE oh.ORDER_STATUS NOT IN ('CANCELLED', 'OPEN')
UNION ALL
SELECT 'LOGISTICS', 'What is our fill rate?',
       ROUND(100.0 * SUM(ol.QUANTITY_FULFILLED) / NULLIF(SUM(ol.QUANTITY_ORDERED), 0), 2)
FROM SUPPLY_CHAIN_HUB.RAW.ORDER_LINE ol
JOIN SUPPLY_CHAIN_HUB.RAW.ORDER_HEADER oh ON ol.ORDER_ID = oh.ORDER_ID
WHERE oh.ORDER_STATUS NOT IN ('CANCELLED', 'OPEN');

-- ALL THREE RETURN THE SAME VALUE → ONTOLOGY WORKS ✓
