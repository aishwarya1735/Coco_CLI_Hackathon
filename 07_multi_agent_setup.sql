-- ============================================================
-- MULTI-AGENT ORCHESTRATION
-- Orchestrator + 3 Specialist Agents
-- ============================================================

-- 1. LOGISTICS SPECIALIST
CREATE OR REPLACE AGENT SUPPLY_CHAIN_HUB.SEMANTIC.LOGISTICS_AGENT
  COMMENT = 'Specialist: shipments, carriers, routes, delivery performance'
  PROFILE = '{"display_name": "Logistics Specialist", "color": "green"}'
  FROM SPECIFICATION $$
  models: { orchestration: auto }
  orchestration: { tool_not_accessible: accept, budget: { seconds: 90, tokens: 24000 } }
  instructions:
    response: >-
      You are a LOGISTICS SPECIALIST. Expert in shipments, carriers, routes, delivery performance, transport costs.
      Key metrics: On-Time Delivery Rate (ACTUAL_DELIVERY_AT <= REQUESTED_DELIVERY_DATE for DELIVERED shipments),
      Shipping Cost (SHIPMENTS.SHIPPING_COST by CARRIERS), Transit Time, Delay Rate.
      If asked about supplier risk or inventory, redirect to the appropriate specialist.
    orchestration: "Use LogisticsAnalyst for shipments, carriers, routes, delivery, shipping costs."
  tools:
    - tool_spec: { type: cortex_analyst_text_to_sql, name: LogisticsAnalyst, description: "Logistics data queries" }
  tool_resources:
    LogisticsAnalyst: { semantic_view: SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY, execution_environment: { type: warehouse, warehouse: COMPUTE_WH } }
  $$;

-- 2. PROCUREMENT SPECIALIST
CREATE OR REPLACE AGENT SUPPLY_CHAIN_HUB.SEMANTIC.PROCUREMENT_AGENT
  COMMENT = 'Specialist: suppliers, parts, pricing, lead times, risk'
  PROFILE = '{"display_name": "Procurement Specialist", "color": "orange"}'
  FROM SPECIFICATION $$
  models: { orchestration: auto }
  orchestration: { tool_not_accessible: accept, budget: { seconds: 90, tokens: 24000 } }
  instructions:
    response: >-
      You are a PROCUREMENT SPECIALIST. Expert in suppliers, parts, pricing, lead times, supplier risk.
      Key metrics: Risk Score, Quality Score, OTD pct, Fill Rate pct (from SUPPLIER_PERFORMANCE, 0-1 scale, multiply by 100 for %).
      If asked about shipment delivery or inventory levels, redirect to the appropriate specialist.
    orchestration: "Use ProcurementAnalyst for suppliers, parts, risk, quality, lead times."
  tools:
    - tool_spec: { type: cortex_analyst_text_to_sql, name: ProcurementAnalyst, description: "Procurement data queries" }
  tool_resources:
    ProcurementAnalyst: { semantic_view: SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY, execution_environment: { type: warehouse, warehouse: COMPUTE_WH } }
  $$;

-- 3. INVENTORY SPECIALIST
CREATE OR REPLACE AGENT SUPPLY_CHAIN_HUB.SEMANTIC.INVENTORY_AGENT
  COMMENT = 'Specialist: stock levels, reorder points, fill rate, demand planning'
  PROFILE = '{"display_name": "Inventory Specialist", "color": "purple"}'
  FROM SPECIFICATION $$
  models: { orchestration: auto }
  orchestration: { tool_not_accessible: accept, budget: { seconds: 90, tokens: 24000 } }
  instructions:
    response: >-
      You are an INVENTORY SPECIALIST. Expert in stock levels, reorder points, safety stock, demand planning.
      Key metrics: Days of Inventory (ON_HAND_QTY / avg_daily_demand), Fill Rate (SUM(SHIPPED_QTY)/SUM(ORDERED_QTY)*100),
      Stock Health (ON_HAND vs SAFETY_STOCK). INVENTORY_STATUS: IN_STOCK, LOW_STOCK, OUT_OF_STOCK, OVERSTOCKED.
      If asked about carrier performance or supplier risk, redirect to the appropriate specialist.
    orchestration: "Use InventoryAnalyst for inventory, stock, fill rate, orders, demand."
  tools:
    - tool_spec: { type: cortex_analyst_text_to_sql, name: InventoryAnalyst, description: "Inventory and demand data queries" }
  tool_resources:
    InventoryAnalyst: { semantic_view: SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY, execution_environment: { type: warehouse, warehouse: COMPUTE_WH } }
  $$;

-- 4. ORCHESTRATOR (routes to specialists)
CREATE OR REPLACE AGENT SUPPLY_CHAIN_HUB.SEMANTIC.ORCHESTRATOR_AGENT
  COMMENT = 'Multi-agent orchestrator. Routes to Logistics, Procurement, or Inventory specialists.'
  PROFILE = '{"display_name": "Supply Chain Orchestrator", "color": "blue"}'
  FROM SPECIFICATION $$
  models: { orchestration: auto }
  orchestration: { tool_not_accessible: accept, budget: { seconds: 120, tokens: 32000 } }
  instructions:
    response: >-
      You are the SUPPLY CHAIN ORCHESTRATOR. Route questions to the right specialist:
      LOGISTICS (LogisticsAnalyst): shipments, delivery, carriers, shipping cost, transit, routes, tracking, delays
      PROCUREMENT (ProcurementAnalyst): suppliers, parts, risk scores, quality, lead times, tier, sourcing
      INVENTORY (InventoryAnalyst): inventory, stock, fill rate, days of inventory, reorder, orders, customer segments
      Cross-domain: use multiple tools. Tag responses: [Logistics] / [Procurement] / [Inventory] / [Cross-Domain]
    orchestration: "Route logistics to LogisticsAnalyst, procurement to ProcurementAnalyst, inventory to InventoryAnalyst."
  tools:
    - tool_spec: { type: cortex_analyst_text_to_sql, name: LogisticsAnalyst, description: "Logistics: shipments, carriers, routes, delivery, shipping costs" }
    - tool_spec: { type: cortex_analyst_text_to_sql, name: ProcurementAnalyst, description: "Procurement: suppliers, parts, risk, quality, lead times" }
    - tool_spec: { type: cortex_analyst_text_to_sql, name: InventoryAnalyst, description: "Inventory: stock, fill rates, orders, customer segments" }
  tool_resources:
    LogisticsAnalyst: { semantic_view: SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY, execution_environment: { type: warehouse, warehouse: COMPUTE_WH } }
    ProcurementAnalyst: { semantic_view: SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY, execution_environment: { type: warehouse, warehouse: COMPUTE_WH } }
    InventoryAnalyst: { semantic_view: SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY, execution_environment: { type: warehouse, warehouse: COMPUTE_WH } }
  $$;
