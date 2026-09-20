-- ============================================================
-- SUPPLY CHAIN ONTOLOGY: DDL + SYNTHETIC DATA
-- Hackathon: Supply Chain Ontology & Governed Conversational Analytics
-- ============================================================
-- Ontology Entities:
--   SUPPLIER → PART → PLANT → INVENTORY
--   CUSTOMER → ORDER → ORDER_LINE → SHIPMENT
-- Canonical Metrics:
--   1. On-Time Delivery Rate (%)
--   2. Fill Rate (%)
--   3. Days of Inventory (days)
--   4. Landed Cost ($)
-- ============================================================

-- 1. DATABASE & SCHEMA SETUP
CREATE DATABASE IF NOT EXISTS SUPPLY_CHAIN_HUB;
USE DATABASE SUPPLY_CHAIN_HUB;

CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS SEMANTIC;

USE SCHEMA RAW;

-- ============================================================
-- 2. CORE ENTITY TABLES
-- ============================================================

-- SUPPLIER: upstream vendors providing parts
CREATE OR REPLACE TABLE SUPPLIER (
    SUPPLIER_ID         VARCHAR(10)   PRIMARY KEY,
    SUPPLIER_NAME       VARCHAR(100)  NOT NULL,
    COUNTRY             VARCHAR(50)   NOT NULL,
    REGION              VARCHAR(30)   NOT NULL,       -- APAC, EMEA, AMERICAS
    TIER                INT           NOT NULL,       -- 1=strategic, 2=preferred, 3=approved
    LEAD_TIME_DAYS      INT           NOT NULL,       -- avg lead time
    RELIABILITY_SCORE   DECIMAL(3,2)  NOT NULL,       -- 0.00 - 1.00
    ONBOARDED_DATE      DATE          NOT NULL
);

-- PART: components/materials sourced from suppliers
CREATE OR REPLACE TABLE PART (
    PART_ID             VARCHAR(10)   PRIMARY KEY,
    PART_NAME           VARCHAR(100)  NOT NULL,
    CATEGORY            VARCHAR(50)   NOT NULL,       -- Electronics, Mechanical, Raw Material, Packaging
    UNIT_COST           DECIMAL(10,2) NOT NULL,
    WEIGHT_KG           DECIMAL(8,3)  NOT NULL,
    IS_CRITICAL          BOOLEAN       NOT NULL DEFAULT FALSE
);

-- SUPPLIER_PART: many-to-many link between suppliers and parts
CREATE OR REPLACE TABLE SUPPLIER_PART (
    SUPPLIER_ID         VARCHAR(10)   NOT NULL REFERENCES SUPPLIER(SUPPLIER_ID),
    PART_ID             VARCHAR(10)   NOT NULL REFERENCES PART(PART_ID),
    UNIT_PRICE          DECIMAL(10,2) NOT NULL,       -- negotiated price from this supplier
    MIN_ORDER_QTY       INT           NOT NULL,
    CONTRACT_START      DATE          NOT NULL,
    CONTRACT_END        DATE,
    PRIMARY KEY (SUPPLIER_ID, PART_ID)
);

-- PLANT: manufacturing or distribution facilities
CREATE OR REPLACE TABLE PLANT (
    PLANT_ID            VARCHAR(10)   PRIMARY KEY,
    PLANT_NAME          VARCHAR(100)  NOT NULL,
    CITY                VARCHAR(50)   NOT NULL,
    COUNTRY             VARCHAR(50)   NOT NULL,
    REGION              VARCHAR(30)   NOT NULL,
    PLANT_TYPE          VARCHAR(30)   NOT NULL,       -- MANUFACTURING, DISTRIBUTION, WAREHOUSE
    CAPACITY_UNITS      INT           NOT NULL
);

-- INVENTORY: current stock at each plant for each part
CREATE OR REPLACE TABLE INVENTORY (
    INVENTORY_ID        VARCHAR(15)   PRIMARY KEY,
    PLANT_ID            VARCHAR(10)   NOT NULL REFERENCES PLANT(PLANT_ID),
    PART_ID             VARCHAR(10)   NOT NULL REFERENCES PART(PART_ID),
    QUANTITY_ON_HAND    INT           NOT NULL,
    REORDER_POINT       INT           NOT NULL,
    SAFETY_STOCK        INT           NOT NULL,
    LAST_REPLENISHED    DATE          NOT NULL,
    SNAPSHOT_DATE       DATE          NOT NULL        -- for point-in-time tracking
);

-- CUSTOMER: downstream buyers
CREATE OR REPLACE TABLE CUSTOMER (
    CUSTOMER_ID         VARCHAR(10)   PRIMARY KEY,
    CUSTOMER_NAME       VARCHAR(100)  NOT NULL,
    SEGMENT             VARCHAR(30)   NOT NULL,       -- ENTERPRISE, MID_MARKET, SMB
    COUNTRY             VARCHAR(50)   NOT NULL,
    REGION              VARCHAR(30)   NOT NULL,
    ACCOUNT_MANAGER     VARCHAR(50)
);

-- ORDER_HEADER: purchase orders from customers
CREATE OR REPLACE TABLE ORDER_HEADER (
    ORDER_ID            VARCHAR(15)   PRIMARY KEY,
    CUSTOMER_ID         VARCHAR(10)   NOT NULL REFERENCES CUSTOMER(CUSTOMER_ID),
    PLANT_ID            VARCHAR(10)   NOT NULL REFERENCES PLANT(PLANT_ID),
    ORDER_DATE          DATE          NOT NULL,
    REQUESTED_DELIVERY  DATE          NOT NULL,
    ORDER_STATUS        VARCHAR(20)   NOT NULL,       -- OPEN, SHIPPED, DELIVERED, CANCELLED
    ORDER_PRIORITY      VARCHAR(10)   NOT NULL        -- HIGH, MEDIUM, LOW
);

-- ORDER_LINE: line items within an order
CREATE OR REPLACE TABLE ORDER_LINE (
    ORDER_LINE_ID       VARCHAR(20)   PRIMARY KEY,
    ORDER_ID            VARCHAR(15)   NOT NULL REFERENCES ORDER_HEADER(ORDER_ID),
    PART_ID             VARCHAR(10)   NOT NULL REFERENCES PART(PART_ID),
    QUANTITY_ORDERED    INT           NOT NULL,
    QUANTITY_FULFILLED  INT           NOT NULL,       -- actual qty shipped (for fill rate)
    LINE_UNIT_PRICE     DECIMAL(10,2) NOT NULL,
    LINE_TOTAL          DECIMAL(12,2) NOT NULL
);

-- SHIPMENT: logistics/transport records
CREATE OR REPLACE TABLE SHIPMENT (
    SHIPMENT_ID         VARCHAR(15)   PRIMARY KEY,
    ORDER_ID            VARCHAR(15)   NOT NULL REFERENCES ORDER_HEADER(ORDER_ID),
    ORIGIN_PLANT_ID     VARCHAR(10)   NOT NULL REFERENCES PLANT(PLANT_ID),
    CARRIER             VARCHAR(50)   NOT NULL,
    SHIP_MODE           VARCHAR(20)   NOT NULL,       -- AIR, OCEAN, TRUCK, RAIL
    SHIP_DATE           DATE          NOT NULL,
    ESTIMATED_ARRIVAL   DATE          NOT NULL,
    ACTUAL_ARRIVAL      DATE,                         -- NULL if in-transit
    FREIGHT_COST        DECIMAL(10,2) NOT NULL,
    CUSTOMS_COST        DECIMAL(10,2) NOT NULL DEFAULT 0,
    INSURANCE_COST      DECIMAL(10,2) NOT NULL DEFAULT 0,
    SHIPMENT_STATUS     VARCHAR(20)   NOT NULL        -- IN_TRANSIT, DELIVERED, DELAYED
);

-- ============================================================
-- 3. SYNTHETIC DATA
-- ============================================================

-- SUPPLIERS (12 suppliers across 3 regions)
INSERT INTO SUPPLIER VALUES
('SUP001', 'TechParts Asia',       'China',       'APAC',     1, 14, 0.94, '2020-03-15'),
('SUP002', 'PrecisionWorks Tokyo', 'Japan',       'APAC',     1,  7, 0.97, '2019-06-01'),
('SUP003', 'ShenZhen Electronics', 'China',       'APAC',     2, 18, 0.88, '2021-01-10'),
('SUP004', 'Bavaria Mechanik',     'Germany',     'EMEA',     1, 10, 0.96, '2018-11-20'),
('SUP005', 'Nordic Components',    'Sweden',      'EMEA',     2, 12, 0.91, '2020-07-05'),
('SUP006', 'Istanbul Materials',   'Turkey',      'EMEA',     3, 20, 0.82, '2022-02-14'),
('SUP007', 'Great Lakes Mfg',      'USA',         'AMERICAS', 1,  5, 0.95, '2019-01-08'),
('SUP008', 'MexiParts SA',         'Mexico',      'AMERICAS', 2,  8, 0.89, '2020-09-22'),
('SUP009', 'BrazilSteel Corp',     'Brazil',      'AMERICAS', 2, 15, 0.86, '2021-04-30'),
('SUP010', 'Vietnam Assembly Co',  'Vietnam',     'APAC',     3, 22, 0.80, '2022-06-18'),
('SUP011', 'Czech Precision',      'Czech Rep',   'EMEA',     2, 11, 0.92, '2020-12-01'),
('SUP012', 'Ontario Plastics',     'Canada',      'AMERICAS', 3,  6, 0.87, '2021-08-15');

-- PARTS (15 parts across 4 categories)
INSERT INTO PART VALUES
('PRT001', 'Microcontroller MCU-A',       'Electronics',   12.50,  0.015, TRUE),
('PRT002', 'Power Regulator IC',          'Electronics',    4.80,  0.008, TRUE),
('PRT003', 'Capacitor Array 100uF',       'Electronics',    0.35,  0.002, FALSE),
('PRT004', 'Aluminum Heatsink',           'Mechanical',     3.20,  0.120, FALSE),
('PRT005', 'Stainless Steel Bracket',     'Mechanical',     7.90,  0.450, FALSE),
('PRT006', 'Precision Bearing 6205',      'Mechanical',    11.40,  0.210, TRUE),
('PRT007', 'Carbon Steel Sheet 2mm',      'Raw Material',  45.00, 12.000, FALSE),
('PRT008', 'Copper Wire Spool 1kg',       'Raw Material',  28.60,  1.000, FALSE),
('PRT009', 'Polycarbonate Resin 25kg',    'Raw Material',  62.00, 25.000, FALSE),
('PRT010', 'Corrugated Box Large',        'Packaging',      1.80,  0.350, FALSE),
('PRT011', 'Anti-Static Foam Insert',     'Packaging',      0.95,  0.080, FALSE),
('PRT012', 'Servo Motor SM-200',          'Electronics',   85.00,  0.680, TRUE),
('PRT013', 'Hydraulic Valve HV-10',       'Mechanical',    42.50,  1.250, TRUE),
('PRT014', 'Rubber Gasket Set',           'Raw Material',   3.10,  0.065, FALSE),
('PRT015', 'Shipping Pallet Wrap',        'Packaging',      8.50,  2.500, FALSE);

-- SUPPLIER_PART (each part has 2-3 suppliers)
INSERT INTO SUPPLIER_PART VALUES
('SUP001', 'PRT001', 11.80, 500,  '2023-01-01', '2025-12-31'),
('SUP002', 'PRT001', 13.20, 200,  '2023-01-01', '2025-12-31'),
('SUP003', 'PRT002',  4.50, 1000, '2023-06-01', '2025-05-31'),
('SUP001', 'PRT002',  4.90, 500,  '2023-06-01', '2025-05-31'),
('SUP003', 'PRT003',  0.30, 5000, '2023-01-01', NULL),
('SUP004', 'PRT004',  3.50, 200,  '2023-03-01', '2025-12-31'),
('SUP005', 'PRT004',  3.10, 300,  '2023-03-01', '2025-12-31'),
('SUP004', 'PRT005',  7.60, 100,  '2022-06-01', '2025-06-30'),
('SUP011', 'PRT005',  8.10, 100,  '2023-01-01', '2025-12-31'),
('SUP004', 'PRT006', 10.90, 150,  '2023-01-01', '2025-12-31'),
('SUP002', 'PRT006', 11.80, 100,  '2023-01-01', '2025-12-31'),
('SUP009', 'PRT007', 42.00, 50,   '2023-04-01', '2025-03-31'),
('SUP007', 'PRT007', 46.50, 30,   '2023-04-01', '2025-03-31'),
('SUP008', 'PRT008', 27.00, 100,  '2023-01-01', '2025-12-31'),
('SUP007', 'PRT008', 29.50, 50,   '2023-01-01', '2025-12-31'),
('SUP012', 'PRT009', 59.00, 20,   '2023-07-01', '2025-06-30'),
('SUP010', 'PRT010',  1.50, 2000, '2023-01-01', NULL),
('SUP012', 'PRT010',  1.90, 1000, '2023-01-01', NULL),
('SUP010', 'PRT011',  0.80, 3000, '2023-01-01', NULL),
('SUP002', 'PRT012', 82.00, 50,   '2023-01-01', '2025-12-31'),
('SUP001', 'PRT012', 84.50, 50,   '2023-06-01', '2025-12-31'),
('SUP004', 'PRT013', 40.00, 30,   '2023-01-01', '2025-12-31'),
('SUP011', 'PRT013', 43.50, 25,   '2023-03-01', '2025-12-31'),
('SUP006', 'PRT014',  2.80, 500,  '2023-01-01', NULL),
('SUP008', 'PRT014',  3.20, 300,  '2023-01-01', NULL),
('SUP010', 'PRT015',  7.80, 500,  '2023-01-01', NULL);

-- PLANTS (6 facilities)
INSERT INTO PLANT VALUES
('PLT001', 'Shanghai Factory',       'Shanghai',    'China',   'APAC',     'MANUFACTURING', 50000),
('PLT002', 'Munich Assembly',        'Munich',      'Germany', 'EMEA',     'MANUFACTURING', 35000),
('PLT003', 'Detroit Plant',          'Detroit',     'USA',     'AMERICAS', 'MANUFACTURING', 45000),
('PLT004', 'Singapore DC',           'Singapore',   'Singapore','APAC',    'DISTRIBUTION',  80000),
('PLT005', 'Rotterdam Hub',          'Rotterdam',   'Netherlands','EMEA',  'DISTRIBUTION',  70000),
('PLT006', 'Dallas Warehouse',       'Dallas',      'USA',     'AMERICAS', 'WAREHOUSE',     60000);

-- INVENTORY (snapshot for multiple parts at multiple plants)
INSERT INTO INVENTORY VALUES
('INV001', 'PLT001', 'PRT001', 2500, 1000, 500, '2025-06-01', '2025-06-15'),
('INV002', 'PLT001', 'PRT002', 8000, 3000, 1500,'2025-06-05', '2025-06-15'),
('INV003', 'PLT001', 'PRT003',45000,15000, 8000,'2025-06-10', '2025-06-15'),
('INV004', 'PLT002', 'PRT004', 1200,  500,  200,'2025-06-03', '2025-06-15'),
('INV005', 'PLT002', 'PRT005',  800,  300,  150,'2025-06-07', '2025-06-15'),
('INV006', 'PLT002', 'PRT006',  600,  250,  100,'2025-05-28', '2025-06-15'),
('INV007', 'PLT003', 'PRT007',  120,   40,   20,'2025-06-12', '2025-06-15'),
('INV008', 'PLT003', 'PRT008',  350,  100,   50,'2025-06-08', '2025-06-15'),
('INV009', 'PLT003', 'PRT012',  180,   60,   30,'2025-06-01', '2025-06-15'),
('INV010', 'PLT004', 'PRT010',15000, 5000, 2500,'2025-06-14', '2025-06-15'),
('INV011', 'PLT004', 'PRT011',20000, 8000, 4000,'2025-06-13', '2025-06-15'),
('INV012', 'PLT005', 'PRT013',  250,  100,   50,'2025-06-02', '2025-06-15'),
('INV013', 'PLT005', 'PRT014', 3500, 1000,  500,'2025-06-09', '2025-06-15'),
('INV014', 'PLT006', 'PRT009',   85,   30,   15,'2025-06-06', '2025-06-15'),
('INV015', 'PLT006', 'PRT015', 2000,  800,  400,'2025-06-11', '2025-06-15'),
('INV016', 'PLT001', 'PRT012',  320,  100,   50,'2025-06-04', '2025-06-15'),
('INV017', 'PLT003', 'PRT006',  450,  200,  100,'2025-06-02', '2025-06-15'),
('INV018', 'PLT002', 'PRT001', 1800,  800,  400,'2025-06-01', '2025-06-15');

-- CUSTOMERS (10 customers across segments and regions)
INSERT INTO CUSTOMER VALUES
('CUS001', 'Global Motors Inc',     'ENTERPRISE',  'USA',       'AMERICAS', 'Sarah Chen'),
('CUS002', 'EuroTech GmbH',        'ENTERPRISE',  'Germany',   'EMEA',     'Marco Schulz'),
('CUS003', 'AsiaFlow Corp',        'ENTERPRISE',  'Japan',     'APAC',     'Yuki Tanaka'),
('CUS004', 'MidWest Manufacturing','MID_MARKET',   'USA',       'AMERICAS', 'Sarah Chen'),
('CUS005', 'Nordic Instruments',   'MID_MARKET',   'Sweden',    'EMEA',     'Marco Schulz'),
('CUS006', 'Pacific Devices',      'MID_MARKET',   'Australia', 'APAC',     'Yuki Tanaka'),
('CUS007', 'QuickBuild LLC',       'SMB',          'USA',       'AMERICAS', 'Jake Morris'),
('CUS008', 'MakerSpace Berlin',    'SMB',          'Germany',   'EMEA',     'Marco Schulz'),
('CUS009', 'StartUp Seoul',        'SMB',          'South Korea','APAC',    'Yuki Tanaka'),
('CUS010', 'LatAm Assembly SA',    'MID_MARKET',   'Mexico',    'AMERICAS', 'Jake Morris');

-- ORDERS (30 orders across 2025 Q1-Q2, mix of statuses)
INSERT INTO ORDER_HEADER VALUES
('ORD001', 'CUS001', 'PLT003', '2025-01-05', '2025-01-20', 'DELIVERED', 'HIGH'),
('ORD002', 'CUS001', 'PLT003', '2025-01-15', '2025-02-01', 'DELIVERED', 'MEDIUM'),
('ORD003', 'CUS002', 'PLT002', '2025-01-20', '2025-02-05', 'DELIVERED', 'HIGH'),
('ORD004', 'CUS003', 'PLT001', '2025-02-01', '2025-02-18', 'DELIVERED', 'HIGH'),
('ORD005', 'CUS004', 'PLT003', '2025-02-10', '2025-02-28', 'DELIVERED', 'MEDIUM'),
('ORD006', 'CUS005', 'PLT002', '2025-02-15', '2025-03-05', 'DELIVERED', 'LOW'),
('ORD007', 'CUS006', 'PLT004', '2025-02-20', '2025-03-10', 'DELIVERED', 'MEDIUM'),
('ORD008', 'CUS007', 'PLT006', '2025-03-01', '2025-03-15', 'DELIVERED', 'LOW'),
('ORD009', 'CUS008', 'PLT005', '2025-03-05', '2025-03-22', 'DELIVERED', 'MEDIUM'),
('ORD010', 'CUS009', 'PLT001', '2025-03-10', '2025-03-28', 'DELIVERED', 'HIGH'),
('ORD011', 'CUS010', 'PLT003', '2025-03-15', '2025-04-01', 'DELIVERED', 'MEDIUM'),
('ORD012', 'CUS001', 'PLT003', '2025-03-20', '2025-04-05', 'DELIVERED', 'HIGH'),
('ORD013', 'CUS002', 'PLT002', '2025-04-01', '2025-04-18', 'DELIVERED', 'MEDIUM'),
('ORD014', 'CUS003', 'PLT001', '2025-04-05', '2025-04-22', 'DELIVERED', 'HIGH'),
('ORD015', 'CUS004', 'PLT006', '2025-04-10', '2025-04-28', 'DELIVERED', 'LOW'),
('ORD016', 'CUS005', 'PLT005', '2025-04-15', '2025-05-02', 'DELIVERED', 'MEDIUM'),
('ORD017', 'CUS006', 'PLT004', '2025-04-20', '2025-05-08', 'DELIVERED', 'HIGH'),
('ORD018', 'CUS007', 'PLT003', '2025-04-25', '2025-05-12', 'DELIVERED', 'LOW'),
('ORD019', 'CUS008', 'PLT002', '2025-05-01', '2025-05-18', 'DELIVERED', 'MEDIUM'),
('ORD020', 'CUS009', 'PLT001', '2025-05-05', '2025-05-22', 'DELIVERED', 'HIGH'),
('ORD021', 'CUS010', 'PLT003', '2025-05-10', '2025-05-28', 'SHIPPED',  'MEDIUM'),
('ORD022', 'CUS001', 'PLT003', '2025-05-15', '2025-06-01', 'SHIPPED',  'HIGH'),
('ORD023', 'CUS002', 'PLT005', '2025-05-20', '2025-06-05', 'SHIPPED',  'MEDIUM'),
('ORD024', 'CUS003', 'PLT004', '2025-05-25', '2025-06-10', 'SHIPPED',  'HIGH'),
('ORD025', 'CUS004', 'PLT003', '2025-06-01', '2025-06-18', 'OPEN',     'MEDIUM'),
('ORD026', 'CUS005', 'PLT002', '2025-06-03', '2025-06-20', 'OPEN',     'LOW'),
('ORD027', 'CUS006', 'PLT004', '2025-06-05', '2025-06-22', 'OPEN',     'HIGH'),
('ORD028', 'CUS001', 'PLT003', '2025-06-08', '2025-06-25', 'OPEN',     'HIGH'),
('ORD029', 'CUS003', 'PLT001', '2025-06-10', '2025-06-28', 'OPEN',     'MEDIUM'),
('ORD030', 'CUS002', 'PLT002', '2025-06-12', '2025-06-30', 'CANCELLED','LOW');

-- ORDER LINES (2-3 lines per order, ~70 lines total)
-- Includes intentional partial fulfillment for fill rate calculation
INSERT INTO ORDER_LINE VALUES
('OL001', 'ORD001', 'PRT001', 500,  500,  12.50, 6250.00),
('OL002', 'ORD001', 'PRT004', 200,  200,   3.20,  640.00),
('OL003', 'ORD002', 'PRT007',  30,   30,  45.00, 1350.00),
('OL004', 'ORD002', 'PRT008', 100,   85,  28.60, 2860.00),
('OL005', 'ORD003', 'PRT005', 150,  150,   7.90, 1185.00),
('OL006', 'ORD003', 'PRT006', 100,  100,  11.40, 1140.00),
('OL007', 'ORD003', 'PRT004', 300,  280,   3.20,  960.00),
('OL008', 'ORD004', 'PRT001', 800,  800,  12.50,10000.00),
('OL009', 'ORD004', 'PRT012', 100,   90,  85.00, 8500.00),
('OL010', 'ORD005', 'PRT008',  50,   50,  28.60, 1430.00),
('OL011', 'ORD005', 'PRT003',5000, 5000,   0.35, 1750.00),
('OL012', 'ORD006', 'PRT005',  80,   80,   7.90,  632.00),
('OL013', 'ORD006', 'PRT014', 400,  350,   3.10, 1240.00),
('OL014', 'ORD007', 'PRT010',3000, 3000,   1.80, 5400.00),
('OL015', 'ORD007', 'PRT011',4000, 3800,   0.95, 3800.00),
('OL016', 'ORD008', 'PRT009',  15,   15,  62.00,  930.00),
('OL017', 'ORD008', 'PRT015', 300,  300,   8.50, 2550.00),
('OL018', 'ORD009', 'PRT013',  40,   40,  42.50, 1700.00),
('OL019', 'ORD009', 'PRT014', 200,  180,   3.10,  620.00),
('OL020', 'ORD010', 'PRT001',1000,  950,  12.50,12500.00),
('OL021', 'ORD010', 'PRT002',2000, 2000,   4.80, 9600.00),
('OL022', 'ORD011', 'PRT007',  20,   20,  45.00,  900.00),
('OL023', 'ORD011', 'PRT006',  80,   75,  11.40,  912.00),
('OL024', 'ORD012', 'PRT012', 150,  150,  85.00,12750.00),
('OL025', 'ORD012', 'PRT001', 600,  600,  12.50, 7500.00),
('OL026', 'ORD013', 'PRT004', 250,  250,   3.20,  800.00),
('OL027', 'ORD013', 'PRT005', 100,   90,   7.90,  790.00),
('OL028', 'ORD014', 'PRT012', 200,  200,  85.00,17000.00),
('OL029', 'ORD014', 'PRT002',1500, 1500,   4.80, 7200.00),
('OL030', 'ORD015', 'PRT009',  25,   25,  62.00, 1550.00),
('OL031', 'ORD015', 'PRT015', 500,  480,   8.50, 4250.00),
('OL032', 'ORD016', 'PRT013',  60,   55,  42.50, 2550.00),
('OL033', 'ORD016', 'PRT014', 300,  300,   3.10,  930.00),
('OL034', 'ORD017', 'PRT010',5000, 5000,   1.80, 9000.00),
('OL035', 'ORD017', 'PRT011',6000, 5500,   0.95, 5700.00),
('OL036', 'ORD018', 'PRT008',  80,   80,  28.60, 2288.00),
('OL037', 'ORD018', 'PRT003',8000, 8000,   0.35, 2800.00),
('OL038', 'ORD019', 'PRT006', 120,  110,  11.40, 1368.00),
('OL039', 'ORD019', 'PRT005', 200,  200,   7.90, 1580.00),
('OL040', 'ORD020', 'PRT001',1200, 1100,  12.50,15000.00),
('OL041', 'ORD020', 'PRT012', 180,  180,  85.00,15300.00),
('OL042', 'ORD021', 'PRT007',  40,   38,  45.00, 1800.00),
('OL043', 'ORD021', 'PRT008', 120,  120,  28.60, 3432.00),
('OL044', 'ORD022', 'PRT001', 700,  700,  12.50, 8750.00),
('OL045', 'ORD022', 'PRT006', 200,  190,  11.40, 2280.00),
('OL046', 'ORD023', 'PRT013',  50,   50,  42.50, 2125.00),
('OL047', 'ORD023', 'PRT005', 150,  140,   7.90, 1185.00),
('OL048', 'ORD024', 'PRT001', 900,  900,  12.50,11250.00),
('OL049', 'ORD024', 'PRT002',1800, 1800,   4.80, 8640.00),
('OL050', 'ORD025', 'PRT012', 100,    0,  85.00, 8500.00),
('OL051', 'ORD025', 'PRT003',6000,    0,   0.35, 2100.00),
('OL052', 'ORD026', 'PRT004', 180,    0,   3.20,  576.00),
('OL053', 'ORD026', 'PRT014', 250,    0,   3.10,  775.00),
('OL054', 'ORD027', 'PRT010',4000,    0,   1.80, 7200.00),
('OL055', 'ORD027', 'PRT011',5000,    0,   0.95, 4750.00),
('OL056', 'ORD028', 'PRT012', 200,    0,  85.00,17000.00),
('OL057', 'ORD028', 'PRT001', 800,    0,  12.50,10000.00),
('OL058', 'ORD029', 'PRT002',2000,    0,   4.80, 9600.00),
('OL059', 'ORD029', 'PRT012', 250,    0,  85.00,21250.00),
('OL060', 'ORD030', 'PRT005', 100,    0,   7.90,  790.00);

-- SHIPMENTS (one per shipped/delivered order)
-- Mix of on-time and late deliveries for OTD metric
INSERT INTO SHIPMENT VALUES
('SHP001', 'ORD001', 'PLT003', 'FedEx Freight',   'TRUCK', '2025-01-08', '2025-01-18', '2025-01-17', 450.00,   0.00,  45.00, 'DELIVERED'),
('SHP002', 'ORD002', 'PLT003', 'UPS Logistics',   'TRUCK', '2025-01-18', '2025-01-30', '2025-02-02', 380.00,   0.00,  38.00, 'DELIVERED'),
('SHP003', 'ORD003', 'PLT002', 'DHL Express',     'TRUCK', '2025-01-23', '2025-02-03', '2025-02-03', 520.00,   0.00,  52.00, 'DELIVERED'),
('SHP004', 'ORD004', 'PLT001', 'Maersk Line',     'OCEAN', '2025-02-04', '2025-02-20', '2025-02-19', 1200.00, 350.00, 120.00,'DELIVERED'),
('SHP005', 'ORD005', 'PLT003', 'FedEx Freight',   'TRUCK', '2025-02-13', '2025-02-26', '2025-02-25', 290.00,   0.00,  29.00, 'DELIVERED'),
('SHP006', 'ORD006', 'PLT002', 'DHL Express',     'TRUCK', '2025-02-18', '2025-03-03', '2025-03-06', 340.00,   0.00,  34.00, 'DELIVERED'),
('SHP007', 'ORD007', 'PLT004', 'Nippon Express',  'AIR',   '2025-02-22', '2025-03-08', '2025-03-07', 1800.00, 200.00, 180.00,'DELIVERED'),
('SHP008', 'ORD008', 'PLT006', 'XPO Logistics',   'TRUCK', '2025-03-03', '2025-03-13', '2025-03-13', 210.00,   0.00,  21.00, 'DELIVERED'),
('SHP009', 'ORD009', 'PLT005', 'DHL Express',     'TRUCK', '2025-03-08', '2025-03-20', '2025-03-21', 410.00,   0.00,  41.00, 'DELIVERED'),
('SHP010', 'ORD010', 'PLT001', 'Maersk Line',     'OCEAN', '2025-03-13', '2025-03-30', '2025-04-02', 1400.00, 380.00, 140.00,'DELIVERED'),
('SHP011', 'ORD011', 'PLT003', 'UPS Logistics',   'TRUCK', '2025-03-18', '2025-03-30', '2025-03-29', 350.00,   0.00,  35.00, 'DELIVERED'),
('SHP012', 'ORD012', 'PLT003', 'FedEx Freight',   'AIR',   '2025-03-22', '2025-04-03', '2025-04-03', 2100.00,  0.00, 210.00, 'DELIVERED'),
('SHP013', 'ORD013', 'PLT002', 'DHL Express',     'TRUCK', '2025-04-04', '2025-04-16', '2025-04-15', 480.00,   0.00,  48.00, 'DELIVERED'),
('SHP014', 'ORD014', 'PLT001', 'Nippon Express',  'OCEAN', '2025-04-08', '2025-04-24', '2025-04-23', 1100.00, 320.00, 110.00,'DELIVERED'),
('SHP015', 'ORD015', 'PLT006', 'XPO Logistics',   'TRUCK', '2025-04-13', '2025-04-26', '2025-04-29', 250.00,   0.00,  25.00, 'DELIVERED'),
('SHP016', 'ORD016', 'PLT005', 'Kuehne+Nagel',    'TRUCK', '2025-04-18', '2025-05-01', '2025-04-30', 390.00,   0.00,  39.00, 'DELIVERED'),
('SHP017', 'ORD017', 'PLT004', 'Nippon Express',  'AIR',   '2025-04-23', '2025-05-06', '2025-05-05', 2400.00, 250.00, 240.00,'DELIVERED'),
('SHP018', 'ORD018', 'PLT003', 'UPS Logistics',   'TRUCK', '2025-04-28', '2025-05-10', '2025-05-10', 310.00,   0.00,  31.00, 'DELIVERED'),
('SHP019', 'ORD019', 'PLT002', 'DHL Express',     'TRUCK', '2025-05-04', '2025-05-16', '2025-05-18', 440.00,   0.00,  44.00, 'DELIVERED'),
('SHP020', 'ORD020', 'PLT001', 'Maersk Line',     'OCEAN', '2025-05-08', '2025-05-24', '2025-05-26', 1500.00, 400.00, 150.00,'DELIVERED'),
('SHP021', 'ORD021', 'PLT003', 'FedEx Freight',   'TRUCK', '2025-05-13', '2025-05-26', '2025-05-27', 420.00,   0.00,  42.00, 'IN_TRANSIT'),
('SHP022', 'ORD022', 'PLT003', 'FedEx Freight',   'AIR',   '2025-05-18', '2025-05-30', NULL,         2300.00,  0.00, 230.00, 'IN_TRANSIT'),
('SHP023', 'ORD023', 'PLT005', 'Kuehne+Nagel',    'TRUCK', '2025-05-23', '2025-06-03', NULL,          360.00,  0.00,  36.00, 'IN_TRANSIT'),
('SHP024', 'ORD024', 'PLT004', 'Nippon Express',  'OCEAN', '2025-05-28', '2025-06-12', NULL,         1300.00, 360.00, 130.00, 'IN_TRANSIT');

-- ============================================================
-- END OF DDL + DATA
-- ============================================================
