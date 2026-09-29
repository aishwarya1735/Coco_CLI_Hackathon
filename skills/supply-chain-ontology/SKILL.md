---
name: supply-chain-ontology
description: >-
  Reusable pattern for building governed domain ontologies with consistent
  conversational analytics. Takes any domain and produces: entity model,
  semantic view, Cortex Agent with guardrails, multi-persona demo app,
  and automated data quality monitoring.
---

# Domain Ontology Builder

Build a governed domain ontology that ensures every team gets the same answer.

## Workflow

1. Define the Domain Ontology (entities, relationships, canonical metrics, personas)
2. Create Tables and Load Data (INFER_SCHEMA + COPY INTO)
3. Build the Semantic View (YAML with VQRs)
4. Create Cortex Agent with Guardrails (scope, quality, governance, safety)
5. Build Multi-Persona Demo App (Streamlit with persona selector)
6. Validate Persona Consistency (same question = same answer)
7. Add Data Quality Automation (daily checks via CoCo automation)

## Adapting to Other Domains

| Supply Chain | Healthcare | Finance |
|-------------|-----------|--------|
| Supplier, Part | Provider, Procedure | Account, Transaction |
| Order, Shipment | Encounter, Claim | Portfolio, Trade |
| OTD Rate, Fill Rate | Readmission Rate, LOS | ROI, Sharpe Ratio |
