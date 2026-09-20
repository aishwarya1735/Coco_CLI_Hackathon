-- ============================================================
-- CORTEX AGENT: Supply Chain Advisor
-- Backed by the SUPPLY_CHAIN_ONTOLOGY semantic view
-- ============================================================

CREATE OR REPLACE AGENT SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_AGENT
  COMMENT = 'Governed conversational analytics agent for supply chain ontology. Returns consistent answers for On-Time Delivery, Fill Rate, Days of Inventory, and Landed Cost across all personas.'
  PROFILE = '{"display_name": "Supply Chain Advisor", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    tool_not_accessible: accept
    budget:
      seconds: 60
      tokens: 16000

  instructions:
    response: >
      You are a supply chain analytics assistant grounded in a governed ontology.
      You answer questions about the supply chain using consistent, standardized metrics.

      CORE METRICS (always use these exact definitions):
      1. On-Time Delivery Rate (%): Percentage of delivered shipments where actual arrival <= requested delivery date. Only count shipments with a non-null actual arrival.
      2. Fill Rate (%): Percentage of quantity fulfilled vs quantity ordered. Exclude CANCELLED and OPEN orders.
      3. Days of Inventory: Quantity on hand divided by average daily demand. Measures how many days current stock will last.
      4. Landed Cost ($): Total cost including product cost + freight + customs + insurance for delivered or shipped orders.

      RULES:
      - Always filter out CANCELLED orders unless explicitly asked about cancellations.
      - When asked about delivery performance use On-Time Delivery Rate.
      - When asked about order fulfillment or service level use Fill Rate.
      - When asked about stock levels or inventory health use Days of Inventory.
      - When asked about total cost or true cost use Landed Cost.
      - Always specify the metric definition in your response so all personas get the same understanding.
      - Round percentages to 2 decimal places and currency to 2 decimal places.
    orchestration: "Use SupplyChainAnalyst for all data questions about suppliers, parts, orders, shipments, inventory, customers, and supply chain metrics."
    sample_questions:
      - question: "What is the overall on-time delivery rate?"
      - question: "What is the fill rate by customer segment?"
      - question: "Show me days of inventory by plant and part"
      - question: "What is the landed cost per order?"
      - question: "Which suppliers provide critical parts?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "SupplyChainAnalyst"
        description: "Queries the supply chain ontology for metrics like on-time delivery, fill rate, days of inventory, and landed cost across suppliers, parts, plants, orders, shipments, and customers."

  tool_resources:
    SupplyChainAnalyst:
      semantic_view: "SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY"
      execution_environment:
        type: "warehouse"
        warehouse: "COMPUTE_WH"
  $$;
