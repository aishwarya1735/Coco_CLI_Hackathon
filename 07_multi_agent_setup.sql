-- ============================================================
-- MULTI-AGENT SETUP: Orchestrator + 3 Specialist Agents + MCP
-- ============================================================

USE DATABASE SUPPLY_CHAIN_HUB;
USE SCHEMA SEMANTIC;

-- See 07_multi_agent_setup.sql in workspace for full agent specs
-- Agents: LOGISTICS_AGENT, PROCUREMENT_AGENT, INVENTORY_AGENT, ORCHESTRATOR_AGENT
-- MCP Server: SUPPLY_CHAIN_MCP

SHOW AGENTS IN SUPPLY_CHAIN_HUB.SEMANTIC;
SHOW MCP SERVERS IN SUPPLY_CHAIN_HUB.SEMANTIC;
