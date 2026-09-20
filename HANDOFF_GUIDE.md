# TEAMMATE HANDOFF GUIDE
# Supply Chain Ontology & Governed Conversational Analytics
# =========================================================

## FILES TO DOWNLOAD (6 files + 1 folder)

Download these from the Snowsight workspace file explorer:

### Required files:
1. `00_FULL_SETUP.sql`          -- All-in-one: DDL + data + semantic view + agent
2. `05_persona_demo_queries.sql` -- Validation queries to prove persona consistency
3. `README.md`                   -- Project overview and demo script

### Streamlit app folder (download all 4 files inside):
4. `04_streamlit_app/snowflake.yml`
5. `04_streamlit_app/pyproject.toml`
6. `04_streamlit_app/.streamlit/config.toml`
7. `04_streamlit_app/04_streamlit_app.py`

### Optional (for reference, not needed to run):
- `01_ddl_and_data.sql`          -- DDL only (already inside 00_FULL_SETUP.sql)
- `02_semantic_model.sv.yaml`    -- Semantic view YAML (already inside 00_FULL_SETUP.sql)
- `03_agent_setup.sql`           -- Agent SQL (already inside 00_FULL_SETUP.sql)


## EXACT STEPS FOR YOUR TEAMMATE

### Prerequisites
- A Snowflake account with ACCOUNTADMIN or equivalent role
- A warehouse (default: COMPUTE_WH)
- A compute pool for Streamlit (run: SHOW COMPUTE POOLS to find yours)
- Cortex AI enabled on the account

### Step 1: Run the setup script (5 minutes)
1. Log into Snowsight
2. Open a SQL Worksheet
3. Paste the entire contents of `00_FULL_SETUP.sql`
4. IF your warehouse is NOT named COMPUTE_WH:
   - Find & Replace: COMPUTE_WH → YOUR_WAREHOUSE_NAME
5. Run ALL statements (Ctrl+Shift+Enter or click "Run All")
6. The final 3 queries validate everything worked:
   - Row counts for all 9 tables
   - DESCRIBE SEMANTIC VIEW confirms the ontology is deployed
   - SHOW AGENTS confirms the agent exists

### Step 2: Deploy the Streamlit app (2 minutes)
1. In Snowsight, go to Projects → Workspaces
2. Create a new folder called `04_streamlit_app`
3. Upload these 4 files into that folder:
   - snowflake.yml
   - pyproject.toml
   - 04_streamlit_app.py
   - .streamlit/config.toml  (create the .streamlit subfolder first)
4. Open `snowflake.yml` and update:
   - query_warehouse: YOUR_WAREHOUSE_NAME
   - compute_pool: YOUR_COMPUTE_POOL_NAME
     (run SHOW COMPUTE POOLS to find it, or use SYSTEM_COMPUTE_POOL_CPU)
5. Open `04_streamlit_app.py` and click **Run**

### Step 3: Validate (2 minutes)
1. Open a SQL Worksheet
2. Paste and run `05_persona_demo_queries.sql`
3. Confirm the CROSS-PERSONA CONSISTENCY PROOF at the bottom:
   - All 3 personas (PLANNING, PROCUREMENT, LOGISTICS) return 97.79% fill rate

### Step 4: Demo the app
1. In the Streamlit app, try each persona:
   - Planning: "What are the days of inventory by plant?"
   - Procurement: "What is the on-time delivery rate by supplier region?"
   - Logistics: "What is the landed cost for our top orders?"
2. Then ask the SAME question from all 3 personas:
   "What is the overall fill rate?"
   → All return 97.79% with the same SQL


## TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| "ROWS is not a valid identifier" | Already fixed in 00_FULL_SETUP.sql |
| Agent returns "missing execution environment" | Check COMPUTE_WH in 03_agent_setup.sql matches your warehouse |
| Streamlit won't start | Verify compute pool in snowflake.yml exists (SHOW COMPUTE POOLS) |
| "insufficient privileges" | Must use ACCOUNTADMIN or role with CREATE AGENT, CREATE DATABASE |
| Semantic view deploy fails | Run each statement individually instead of Run All |


## EXPECTED METRIC VALUES (for validation)

| Metric | Expected Value |
|--------|---------------|
| On-Time Delivery Rate | 66.67% |
| Fill Rate (overall) | 97.79% |
| Fill Rate (Enterprise) | 99.16% |
| Fill Rate (Mid-Market) | 96.83% |
| Fill Rate (SMB) | 98.65% |
| Top Landed Cost Order | ORD020 = $34,400.00 |
