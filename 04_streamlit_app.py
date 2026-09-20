"""
Supply Chain Ontology — Governed Conversational Analytics
Hackathon Demo: Streamlit app backed by a Cortex Agent
"""
import os
import json
import streamlit as st

st.set_page_config(page_title="Supply Chain Advisor", page_icon=":factory:", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

AGENT_FQN = "SUPPLY_CHAIN_HUB.SEMANTIC.SUPPLY_CHAIN_AGENT"

PERSONA_CONTEXTS = {
    "Planning": "I am a supply chain planning analyst focused on inventory levels, demand, and production scheduling.",
    "Procurement": "I am a procurement manager focused on supplier performance, pricing, lead times, and sourcing.",
    "Logistics": "I am a logistics coordinator focused on shipments, carriers, delivery timelines, and transport costs.",
}

SAMPLE_QUESTIONS = {
    "Planning": [
        "What are the days of inventory by plant and part?",
        "What is the overall fill rate?",
        "Which parts have the lowest days of inventory?",
    ],
    "Procurement": [
        "Which suppliers provide critical parts and what are their prices?",
        "What is the on-time delivery rate by supplier region?",
        "Show me supplier reliability scores by tier",
    ],
    "Logistics": [
        "What is the overall on-time delivery rate?",
        "What is the average shipping cost by carrier and ship mode?",
        "What is the landed cost for the top 5 orders?",
    ],
}

if "messages" not in st.session_state:
    st.session_state.messages = []
if "persona" not in st.session_state:
    st.session_state.persona = "Planning"


def call_agent(question: str, persona: str) -> dict:
    """Call the Cortex Agent via DATA_AGENT_RUN and return parsed response."""
    context = PERSONA_CONTEXTS[persona]
    full_query = f"[Persona: {persona}. Context: {context}] {question}"

    request_body = json.dumps({
        "messages": [{"role": "user", "content": [{"type": "text", "text": full_query}]}],
        "stream": False,
    })

    row = conn.query(
        "SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(:1, :2)) AS resp",
        params=[AGENT_FQN, request_body],
    )
    resp = row.iloc[0]["RESP"]
    if isinstance(resp, str):
        resp = json.loads(resp)

    answer_text = ""
    sql_text = ""
    if resp and "content" in resp:
        for item in resp["content"]:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    answer_text += item.get("text", "")
                elif item.get("type") == "tool_result":
                    for c in item.get("content", []):
                        if isinstance(c, dict) and "json" in c:
                            if "sql" in c["json"]:
                                sql_text = c["json"]["sql"]
    if not answer_text and resp:
        answer_text = json.dumps(resp, indent=2)

    return {"text": answer_text, "sql": sql_text}


# ── Sidebar ──
with st.sidebar:
    st.title(":factory: Supply Chain Advisor")
    st.caption("Governed Conversational Analytics")
    st.divider()

    st.subheader("Select Persona")
    persona = st.radio(
        "Your role:",
        ["Planning", "Procurement", "Logistics"],
        index=["Planning", "Procurement", "Logistics"].index(st.session_state.persona),
        help="Switch personas to prove consistent answers across teams.",
    )
    if persona != st.session_state.persona:
        st.session_state.persona = persona

    st.divider()
    st.subheader("Ontology")
    st.markdown("""
**Entities:** Supplier :arrow_right: Part :arrow_right: Plant :arrow_right: Inventory

**Demand side:** Customer :arrow_right: Order :arrow_right: Shipment

**Canonical Metrics:**
| Metric | Definition |
|--------|-----------|
| OTD Rate | % shipments on time |
| Fill Rate | % qty fulfilled |
| Days of Inv. | Stock / daily demand |
| Landed Cost | Product + freight + customs + insurance |
""")

    st.divider()
    if st.button("Clear conversation", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

# ── Main area ──
col_header, col_badge = st.columns([3, 1])
with col_header:
    st.header("Supply Chain Advisor")
with col_badge:
    st.markdown(
        f"<div style='text-align:right; padding-top:16px;'>"
        f"<span style='background:#1B73E8; color:white; padding:4px 12px; border-radius:12px; font-size:14px;'>"
        f"{st.session_state.persona}</span></div>",
        unsafe_allow_html=True,
    )

st.caption("Ask any supply chain question. The governed semantic layer ensures consistent, trustworthy answers across all personas.")

# Sample questions as suggestion pills
if not st.session_state.messages:
    samples = SAMPLE_QUESTIONS[st.session_state.persona]
    suggestion_labels = {f":blue[:material/search:] {q}": q for q in samples}
    selected = st.pills("Try asking:", list(suggestion_labels.keys()), label_visibility="collapsed")
    if selected:
        st.session_state.messages.append({"role": "user", "content": suggestion_labels[selected]})
        st.rerun()

# Chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if msg.get("sql"):
            with st.expander("Generated SQL"):
                st.code(msg["sql"], language="sql")

# Chat input
if prompt := st.chat_input("Ask about the supply chain..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    st.rerun()

# Process last user message
if st.session_state.messages and st.session_state.messages[-1]["role"] == "user":
    user_msg = st.session_state.messages[-1]["content"]

    with st.chat_message("assistant"):
        with st.spinner("Querying the governed supply chain ontology..."):
            try:
                result = call_agent(user_msg, st.session_state.persona)
                st.markdown(result["text"])
                if result["sql"]:
                    with st.expander("Generated SQL"):
                        st.code(result["sql"], language="sql")
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": result["text"],
                    "sql": result["sql"],
                })
            except Exception as e:
                error_msg = f"Error communicating with agent: {e}"
                st.error(error_msg)
                st.session_state.messages.append({"role": "assistant", "content": error_msg})
