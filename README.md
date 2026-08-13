# STM ↔ DBT Verifier

Automated comparison tool that verifies STM Excel workbooks against DBT/SQL code and generates structured gap analysis reports.

## Quick Start

```bash
cd DBT_STM_Comparison
.venv\Scripts\activate
python server\app.py
```

Open `http://localhost:5000`

## How It Works

1. **Select LOB** — BOP or CA (auto-detects files from `data/` folder)
2. **Select Model** — click a model → comparison runs automatically
3. **View Results** — 4 tabs:
   - **Comparison** — side-by-side table with summary, filters, frozen headers
   - **STM Data** — raw STM columns with source mapping and business rules
   - **SQL Code** — original raw SQL (with Jinja `{{ }}` if present)
   - **Compiled Code** — fully expanded SQL (macros resolved at runtime)

## Key Features

- **Runtime macro compilation** — `m_int_term`, `m_cleansing`, `m_scd2_scd1_int_stage_dedup` expanded to full SQL
- **JSON column extraction** — `struct_pack`/`object_construct` keys parsed as individual columns
- **Auto-refresh** — F5 re-runs comparison with latest files (no re-upload)
- **Frozen headers** — table headers stick when scrolling
- **Smart matching** — normalizes (PK)/(FK) suffixes, spaces vs underscores
- **Cleansing rule detection** — identifies VARCHAR_NOKEY, NUMERIC_ZERO, etc. from expressions

## Comparison Output

Each column shows:
| Field | Description |
|-------|-------------|
| STM Column | Target column from STM |
| DBT Column | Matching column in DBT (or `-`) |
| Column Compare | MATCH / MISMATCH (space vs underscore) / NOT FOUND |
| STM DataType | Type from STM |
| DBT DataType | Inferred from m_cleansing + expression syntax |
| DataType Compare | MATCH or MISMATCH |
| Column Logic | Mapped as per STM / Intentional NULL / Missing |
| Transformation | Direct Pass-through / COALESCE / CASE Logic / Type Cast |
| Source Expression | Full DBT mapping expression |
| Suggestion | No action required / Review needed |

## Project Structure

```
DBT_STM_Comparison/
├── server/                  # Flask web app
│   ├── app.py               # Entry point (port 5000)
│   ├── routes/              # API endpoints
│   ├── templates/           # HTML (Jinja2 + Tailwind)
│   └── static/js/app.js    # Frontend logic
├── services/                # Core engine
│   ├── dbt_compiler.py      # Runtime macro expansion
│   ├── excel_parser.py      # STM parser (auto-detect headers)
│   ├── sql_parser.py        # Column extraction (sqlglot + regex + JSON + macro)
│   ├── rule_engine.py       # Comparison rules
│   ├── comparator.py        # Orchestrator
│   └── report_generator.py  # .xlsx generation
├── data/
│   ├── stm/                 # STM workbooks
│   ├── sql/bop/             # BOP SQL files
│   ├── sql/ca/              # CA SQL files
│   ├── macros/              # DBT macro .sql files (41 files)
│   └── results/             # Output per run
├── requirements.txt
└── .env.example
```

## Technology Stack

- Python 3.12 + Flask
- openpyxl (Excel read/write)
- sqlglot (SQL parsing, Snowflake dialect)
- Tailwind CSS via CDN (dark theme)
