# Implementation Details

## Architecture

```
Browser (localhost:5000)
    ↓ GET /api/lobs → list available LOBs
    ↓ GET /api/lobs/<lob>/models → list models
    ↓ POST /api/compare → run comparison
    ↓ GET /api/models/<name>/compiled → runtime-compiled SQL
Flask Server
    ↓ reads from data/ directories
Services Layer
    ├── dbt_compiler.py     → expands macros from data/macros/ at runtime
    ├── excel_parser.py     → reads STM columns (auto-detect headers)
    ├── model_matcher.py    → maps SQL files to STM tabs
    ├── jinja_preprocessor.py → strips Jinja for parser (keeps metadata)
    ├── sql_parser.py       → extracts columns (sqlglot + regex + JSON + macro)
    ├── rule_engine.py      → compares column by column
    ├── comparator.py       → orchestrates pipeline
    └── report_generator.py → writes .xlsx output
```

## API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/` | Wizard UI |
| GET | `/api/lobs` | List LOBs with file counts |
| GET | `/api/lobs/<lob>/models` | List models for a LOB |
| GET | `/api/models/<name>/details?lob=x` | STM columns for a model |
| GET | `/api/models/<name>/sql?lob=x` | Raw SQL content |
| GET | `/api/models/<name>/compiled?lob=x` | Runtime-compiled SQL (macros expanded) |
| POST | `/api/compare` | Run comparison `{models: [...], lob: "ca"}` |
| GET | `/api/results/download/<name>` | Download .xlsx |
| GET | `/api/results/download-all` | Download all as .zip |

## DBT Compiler (services/dbt_compiler.py)

Runtime macro expansion — reads macro definitions and substitutes parameters:

| Macro | Expansion |
|-------|-----------|
| `{{ m_cleanse('VARCHAR_NOKEY', 'COL') }}` | `(CASE WHEN COL IS NULL OR TRIM(COL)='' THEN 'NOKEY' ELSE TRIM(COL) END)` |
| `{{ m_cleanse('DATE_LOW', 'COL') }}` | `(CASE WHEN COL IS NULL THEN TO_DATE('1900-01-01') ELSE COL END)` |
| `{{ m_cleanse('NUMERIC_ZERO', 'COL') }}` | `(CASE WHEN COL IS NULL THEN 0 ELSE COL END)` |
| `{{ m_int_term(...) }}` | Full 150+ line SQL with CTEs, joins, OBJECT_AGG, cleansing, SCD dedup |
| `{{ source('s', 't') }}` | `s.t` |
| `{{ ref('model') }}` | `model` |
| `{{ config(...) }}` | removed |
| `{% if %}...{% else %}...{% endif %}` | keeps else branch |

## Column Extraction Pipeline (sql_parser.py)

1. Jinja preprocessing → strip + record m_cleanse metadata
2. sqlglot parse → find SELECT with most columns (skip SELECT *)
3. Regex `_cleaned` CTE → paren-depth-aware FROM detection
4. struct_pack/object_construct → extract KEY := expr pairs
5. m_int_term expansion → 18 standard columns from parameters
6. Dedup → prefer CASE > function > direct ref > NULL

## DataType Inference (rule_engine.py)

Only from m_cleansing metadata and expression syntax:

| Source | Inferred Type |
|--------|---------------|
| m_cleanse('VARCHAR_*', col) | VARCHAR |
| m_cleanse('DATE_*', col) | DATE |
| m_cleanse('NUMERIC_ZERO', col) | NUMBER |
| m_cleanse('TIMESTAMP_NTZ_*', col) | TIMESTAMP_NTZ |
| CAST(... AS type) | type |
| 'literal' \|\| 'concat' | VARCHAR |
| CASE WHEN ... THEN 'Y' | VARCHAR |
| SUM/COUNT/AVG(...) | NUMBER |
| coalesce(..., 0) in struct_pack | NUMBER |
| coalesce(nullif(cast(... as varchar)), ' ') | VARCHAR |

## Column Name Matching

1. Strip (PK), (FK) suffixes
2. Replace spaces with underscores
3. Case-insensitive compare
4. Space vs underscore → MISMATCH (STM typo)
5. Cross-check unmatched by expression → NAME MISMATCH

## Summary Calculation

- matched + mismatched = total STM columns (always adds up)
- extra_in_dbt tracked separately
- match_rate = matched / (matched + mismatched)
- status = MISMATCH if column name OR datatype mismatches

## Output (.xlsx)

Sheet 1 "Detailed Comparison": STM Column, DBT Column, Column Name Compare, STM DataType, DBT DataType, DataType Comparison, Column Logic, Transformation, Source Expression, Suggestion

Sheet 2 "Summary": Totals, match rate, transformation breakdown
