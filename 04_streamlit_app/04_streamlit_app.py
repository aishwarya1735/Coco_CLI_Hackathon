"""
Supply Chain Ontology - Multi-Agent Analytics + Dashboard
Hackathon Demo: Chat with agents + visual KPI dashboard
v2 - No external dependencies, uses only built-in Streamlit charts
"""
import os
import json
import streamlit as st

st.set_page_config(page_title="Supply Chain Advisor", page_icon=":factory:", layout="wide")
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
DB = "SUPPLY_CHAIN_HUB.RAW"

AGENTS = {
    "Orchestrator": "SUPPLY_CHAIN_HUB.SEMANTIC.ORCHESTRATOR_AGENT",
    "Logistics": "SUPPLY_CHAIN_HUB.SEMANTIC.LOGISTICS_AGENT",
    "Procurement": "SUPPLY_CHAIN_HUB.SEMANTIC.PROCUREMENT_AGENT",
    "Inventory": "SUPPLY_CHAIN_HUB.SEMANTIC.INVENTORY_AGENT",
    "Generalist": "SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_AGENT",
}
AGENT_COLORS = {"Orchestrator": "#1B73E8", "Logistics": "#0F9D58", "Procurement": "#F4B400", "Inventory": "#AB47BC", "Generalist": "#1B73E8"}
PERSONA_AGENTS = {"Planning": "Inventory", "Procurement": "Procurement", "Logistics": "Logistics"}
PERSONA_CONTEXTS = {
    "Planning": "I am a supply chain planning analyst focused on inventory levels, demand, and production scheduling.",
    "Procurement": "I am a procurement manager focused on supplier performance, pricing, lead times, and sourcing.",
    "Logistics": "I am a logistics coordinator focused on shipments, carriers, delivery timelines, and transport costs.",
}
SAMPLE_QUESTIONS = {
    "Planning": ["What are the days of inventory by plant?", "What is the overall fill rate?", "What is the monthly order volume trend?"],
    "Procurement": ["Which suppliers have the highest risk scores?", "What is the average lead time by supplier tier?", "Show me quality scores for Tier 1 suppliers"],
    "Logistics": ["What is the overall on-time delivery rate?", "What is the average shipping cost by carrier?", "Which routes have the highest risk level?"],
}

# See full source in workspace: 04_streamlit_app/04_streamlit_app.py
# This file contains: Dashboard with KPIs, filters, charts + Multi-agent chat interface
