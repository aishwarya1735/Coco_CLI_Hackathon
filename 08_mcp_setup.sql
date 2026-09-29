-- ============================================================
-- MCP SERVER SETUP
-- Snowflake-managed MCP server + GitHub External MCP connector
-- ============================================================

-- 1. Snowflake-managed MCP Server (exposes agents to external MCP clients)
CREATE OR REPLACE MCP SERVER SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_MCP
  FROM SPECIFICATION $$
  tools:
    - title: "Supply Chain Orchestrator Agent"
      name: "supply_chain_orchestrator"
      type: "CORTEX_AGENT_RUN"
      identifier: "SUPPLY_CHAIN_HUB.SEMANTIC.ORCHESTRATOR_AGENT"
      description: "Multi-agent orchestrator for supply chain analytics. Routes to specialists."
    - title: "Supply Chain Analyst (Semantic View)"
      name: "supply_chain_analyst"
      type: "CORTEX_ANALYST_MESSAGE"
      identifier: "SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_ONTOLOGY"
      description: "Direct text-to-SQL against the governed semantic view."
    - title: "Supply Chain SQL (Read-Only)"
      name: "supply_chain_sql"
      type: "SYSTEM_EXECUTE_SQL"
      description: "Read-only SQL execution for custom analytics."
      config:
        read_only: true
        query_timeout: 120
        warehouse: "COMPUTE_WH"
  $$;

-- MCP Endpoint URL: https://<account>.snowflakecomputing.com/api/v2/databases/SUPPLY_CHAIN_HUB/schemas/SEMANTIC/mcp-servers/SUPPLY_CHAIN_MCP

-- 2. GitHub External MCP Connector (set up via Snowsight UI)
-- Go to: AI & ML > Agents > Settings > Tools and Connectors > Browse Connectors > GitHub
-- Requires: GitHub OAuth App with callback URL: https://identity.snowflake.com/oauth2/callback
-- After setup, the GitHub MCP can be used in CoCo automations with --mcp flag

-- Verify:
SHOW MCP SERVERS IN SUPPLY_CHAIN_HUB.SEMANTIC;
SHOW EXTERNAL MCP SERVERS IN SUPPLY_CHAIN_HUB.SEMANTIC;
DESCRIBE MCP SERVER SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_MCP;
