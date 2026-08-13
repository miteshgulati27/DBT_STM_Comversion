# STM ↔ DBT Verifier — Claude Context

## How to Run
```bash
cd DBT_STM_Comparison
.venv\Scripts\python.exe server\app.py
# Open http://localhost:5000
```

## Project Layout
- `server/app.py` — Flask entry point (port 5000)
- `server/templates/base.html` — Base layout (Tailwind + sticky header CSS)
- `server/templates/index.html` — Wizard UI: 3 steps + 4 view tabs (Comparison, STM Data, SQL Code, Compiled Code)
- `server/static/js/app.js` — Frontend (localStorage restore, LOB selection, auto-compare, view tabs)
- `server/routes/upload.py` — LOB listing API (`/api/lobs`, `/api/lobs/<lob>/models`)
- `server/routes/models.py` — Model details + SQL + compiled endpoints
- `server/routes/compare.py` — Comparison execution + download
- `services/dbt_compiler.py` — Runtime Jinja macro expansion (m_int_term, m_cleansing, m_scd2_scd1)
- `services/excel_parser.py` — STM parser (auto-detects: "column mapping", "general rule applied", etc.)
- `services/model_matcher.py` — SQL filename → STM tab via alias table
- `services/jinja_preprocessor.py` — Lightweight Jinja strip for SQL parser (records m_cleanse metadata)
- `services/sql_parser.py` — Column extraction: sqlglot + _cleaned CTE regex + struct_pack JSON + m_int_term
- `services/rule_engine.py` — Comparison: name normalization, datatype from m_cleansing + expression only, source expression
- `services/comparator.py` — Orchestrator (matched + mismatched = total STM)
- `services/report_generator.py` — .xlsx with frozen headers, color-coded cells

## Data Organization
```
data/stm/BOP_CVRBL_STM_1.xlsx                     # BOP STM (5 tabs)
data/stm/Commercial Auto Data Specifications.xlsx   # CA STM (56 tabs)
data/sql/bop/int_gwpc_bop_*.sql                    # 4 BOP compiled SQL
data/sql/ca/int_gwpc_ca_*.sql                      # 6 CA SQL (raw Jinja)
data/macros/*.sql                                   # 41 macro files (used by compiler)
data/results/<timestamp>/                           # Output per run
```

## LOB Configuration (server/routes/upload.py)
```python
LOB_CONFIG = {
    "bop": {"stm_file": "BOP_CVRBL_STM_1.xlsx", "sql_folder": "bop"},
    "ca": {"stm_file": "Commercial Auto Data Specifications.xlsx", "sql_folder": "ca"},
}
```

## Key Design Decisions
- DataType inference: ONLY from m_cleansing macro metadata + expression syntax. No column-name guessing.
- Column name: space vs underscore = MISMATCH (flags STM typo)
- Source expression: shows full DBT expression as-is
- Missing columns: show `-` for all DBT fields
- Compiled Code tab: uses dbt_compiler.py to expand macros at runtime (not dbt compile)
- Auto-refresh: localStorage saves {lob, model}, F5 re-runs with latest files
- Summary: matched + mismatched = total STM columns (always adds up)
- Extra in DBT tracked separately
