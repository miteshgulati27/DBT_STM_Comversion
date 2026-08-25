import re
from pathlib import Path
from services.excel_parser import parse_stm_workbook, get_tab_columns
from services.sql_parser import parse_sql_file, parse_compiled_sql
from services.dbt_compiler import compile_sql
from services.model_matcher import match_models, _extract_entity_name, _find_best_tab_match
from services.rule_engine import compare_columns


def _resolve_ref_model(sql_path: Path, sql_dir: Path) -> Path:
    """If the SQL file is a ref-only/union model (select * from ref(...)),
    resolve to the first referenced sub-model that has actual SQL logic."""
    content = sql_path.read_text(encoding="utf-8").strip()
    refs = re.findall(r"\{\{\s*ref\s*\(\s*['\"](\w+)['\"]\s*\)\s*\}\}", content)
    if not refs:
        return sql_path

    lines = [l.strip() for l in content.splitlines() if l.strip() and not l.strip().startswith("--")]
    is_ref_only = all(
        re.match(r"^(select\s+\*\s+from\s+\{\{|union\s+all|--)", l, re.IGNORECASE)
        for l in lines
    )

    if not is_ref_only:
        return sql_path

    for ref_name in refs:
        ref_path = sql_dir / f"{ref_name}.sql"
        if ref_path.exists():
            return ref_path

    return sql_path


def run_comparison(model_name: str, stm_path: Path, sql_dir: Path, macros_dir: Path, stm_tab_override: str = None) -> dict:
    """Run full comparison for a single model."""
    stm_tabs = parse_stm_workbook(stm_path)

    if stm_tab_override:
        stm_tab = stm_tab_override
    else:
        entity_name = _extract_entity_name(model_name)
        stm_tab = _find_best_tab_match(entity_name, stm_tabs.keys())

    if not stm_tab:
        raise ValueError(f"Could not match model '{model_name}' to any STM tab")

    stm_columns = get_tab_columns(stm_path, stm_tab)
    if not stm_columns:
        raise ValueError(f"No columns found in STM tab '{stm_tab}'")

    sql_path = sql_dir / f"{model_name}.sql"
    if not sql_path.exists():
        raise FileNotFoundError(f"SQL file not found: {model_name}.sql")

    resolved_path = _resolve_ref_model(sql_path, sql_dir)
    parsed_sql = parse_sql_file(resolved_path)
    dbt_columns = parsed_sql["columns"]
    jinja_metadata = parsed_sql["jinja_metadata"]

    # Compile SQL (macro-expand) and extract per-column compiled expressions
    compiled_expressions = {}
    try:
        compiled_sql = compile_sql(resolved_path, macros_dir)
        compiled_parsed = parse_compiled_sql(compiled_sql)
        for col in compiled_parsed["columns"]:
            compiled_expressions[col["column_name"].upper()] = col.get("expression", "")
    except Exception:
        pass

    detailed_results = compare_columns(stm_columns, dbt_columns, jinja_metadata, compiled_expressions)

    summary = _build_summary(stm_columns, dbt_columns, detailed_results)

    return {
        "model_name": model_name,
        "stm_tab": stm_tab,
        "summary": summary,
        "detailed": detailed_results,
    }


def _build_summary(stm_columns: list, dbt_columns: list, detailed: list) -> dict:
    total_stm = len(stm_columns)
    total_dbt = len(dbt_columns)

    stm_rows = [r for r in detailed if r.get("stm_column") and r["stm_column"] != "-"]
    matched = sum(1 for r in stm_rows if r.get("status") == "MATCH")
    mismatched = sum(1 for r in stm_rows if r.get("status") == "MISMATCH")
    extra_in_dbt = sum(1 for r in detailed if r.get("stm_column") == "-")

    total_compared = matched + mismatched
    match_rate = f"{(matched / total_compared * 100):.1f}%" if total_compared > 0 else "0%"

    return {
        "total_stm_columns": total_stm,
        "total_dbt_columns": total_dbt,
        "matched_columns": matched,
        "extra_in_dbt": extra_in_dbt,
        "match_rate": match_rate,
        "datatype_mismatches": mismatched,
    }
