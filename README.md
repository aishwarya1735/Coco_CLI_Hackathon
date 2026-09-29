# Supply Chain Ontology & Governed Conversational Analytics

## Problem Statement
Supply chain data is scattered across ERP, logistics, supplier, and IoT systems with inconsistent definitions. The same question yields different answers across teams.

## Solution
An **industry supply chain ontology** expressed as **governed semantic views** with **multi-agent orchestration** providing natural language access — ensuring every team (Planning, Procurement, Logistics) gets the **same consistent answer**.

## Architecture

```
External MCP Clients (Claude, LangGraph)
         |
    MCP SERVER (SUPPLY_CHAIN_MCP)
         |
    Orchestrator Agent
    |-- Logistics Agent (shipments, carriers, routes)
    |-- Procurement Agent (suppliers, parts, risk)
    |-- Inventory Agent (stock, fill rate, orders)
         |
    Semantic View (SUPPLY_CHAIN_ONTOLOGY)
         |
    15 Tables (2.66M+ rows from S3)
         |
    Pipeline (Task -> Stream -> 3 Dynamic Tables)
```

## What We Built

| Component | Details |
|-----------|--------|
| **Data** | 15 tables, 2.66M+ rows loaded from 538 S3 CSVs |
| **Semantic View** | 820-line YAML, 15 tables, 15 relationships, 8 VQRs |
| **Agents** | 5 total: Orchestrator + Logistics/Procurement/Inventory specialists + Generalist |
| **Guardrails** | 4-layer: scope detection, data quality awareness, metric governance, safety rails |
| **Dashboard** | Streamlit with KPIs, filters, charts, data explorer |
| **Pipeline** | Task (5-min) + Stream + 3 Dynamic Tables for near-real-time |
| **MCP Server** | Exposes agents to external MCP clients |
| **GitHub MCP** | Auto-creates GitHub issues for supply chain alerts |
| **Automation** | Daily DQ monitor at 8am IST, emails report |
| **Skill** | Reusable CoCo skill for domain ontology pattern |

## Key Metrics

| Metric | Value |
|--------|-------|
| On-Time Delivery Rate | 58.69% |
| Overall Fill Rate | 40.73% (identical across all 3 personas) |
| Fill Rate (Enterprise) | 40.67% |
| Fill Rate (Mid-Market) | 40.90% |
| Fill Rate (SMB) | 40.61% |

## Files

| File | Purpose |
|------|--------|
| `01_ddl_and_data.sql` | Original DDL + synthetic data |
| `02_semantic_model.sv.yaml` | Semantic view YAML (the ontology) |
| `03_agent_setup.sql` | Generalist agent with guardrails |
| `04_streamlit_app/` | Multi-agent Streamlit app with dashboard |
| `05_persona_demo_queries.sql` | Cross-persona consistency validation |
| `06_pipeline_setup.sql` | Near-real-time pipeline (Task+Stream+DT) |
| `07_multi_agent_setup.sql` | Specialist agents + orchestrator |
| `08_mcp_setup.sql` | MCP server + GitHub connector |
| `automation_dq_prompt.md` | Daily DQ automation prompt |
| `skills/supply-chain-ontology/` | Reusable CoCo skill |

## CoCo Usage (Every Phase)

- **Planning**: Explored S3 data, designed ontology, planned architecture
- **Development**: Generated DDL, YAML, agent SQL, Streamlit app, pipeline code
- **Execution**: Loaded 538 files, deployed semantic view, agents, MCP server
- **Testing**: Validated persona consistency, tested all agents
- **Operations**: Daily DQ automation, GitHub MCP alerts
