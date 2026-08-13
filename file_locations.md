# File Locations Reference

## HTML / UI Files
| File | Path | Purpose |
|------|------|---------|
| Base template | `server/templates/base.html` | Layout, Tailwind config, sticky header CSS |
| Main wizard | `server/templates/index.html` | 3 steps + 4 view tabs |
| JavaScript | `server/static/js/app.js` | Wizard state, localStorage, auto-compare, view switching |

## Server / API Files
| File | Path | Purpose |
|------|------|---------|
| App entry | `server/app.py` | Flask app factory |
| Config | `server/config.py` | Paths, limits, env vars |
| Upload/LOB API | `server/routes/upload.py` | /api/lobs, /api/lobs/<lob>/models |
| Models API | `server/routes/models.py` | /details, /sql, /compiled endpoints |
| Compare API | `server/routes/compare.py` | /api/compare, /download |
| Pages | `server/routes/pages.py` | GET / serves UI |

## Services (Core Logic)
| File | Path | Purpose |
|------|------|---------|
| DBT Compiler | `services/dbt_compiler.py` | Runtime macro expansion (m_int_term, m_cleansing) |
| Excel Parser | `services/excel_parser.py` | STM reader (auto-detect headers) |
| Model Matcher | `services/model_matcher.py` | SQL filename → STM tab via aliases |
| Jinja Preprocessor | `services/jinja_preprocessor.py` | Strips Jinja for parser, records metadata |
| SQL Parser | `services/sql_parser.py` | Column extraction (sqlglot + regex + JSON + macro) |
| Rule Engine | `services/rule_engine.py` | Comparison, datatype inference, name normalization |
| Comparator | `services/comparator.py` | Orchestrator, summary builder |
| Report Generator | `services/report_generator.py` | .xlsx with frozen headers, color cells |

## Data Directories
| Directory | Contents |
|-----------|----------|
| `data/stm/` | BOP_CVRBL_STM_1.xlsx, Commercial Auto Data Specifications.xlsx |
| `data/sql/bop/` | 4 BOP compiled SQL models |
| `data/sql/ca/` | 6 CA SQL models (raw Jinja — compiled at runtime) |
| `data/macros/` | 41 macro .sql files (m_cleansing, m_int_term, etc.) |
| `data/results/` | Output: timestamped folders with .xlsx + run_log.txt |

## Documentation
| File | Purpose |
|------|---------|
| `README.md` | Quick start + feature overview |
| `run_steps.txt` | Step-by-step instructions |
| `implementation.md` | Technical details, API, compiler, inference rules |
| `CLAUDE.md` | Context for Claude Code sessions |
| `file_locations.md` | This file |
| `requirements.txt` | Python dependencies |
| `.env.example` | Environment variable template |
