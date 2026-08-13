from pathlib import Path
from services.excel_parser import parse_stm_workbook, get_tab_columns
from services.sql_parser import parse_sql_file
from services.model_matcher import match_models, _extract_entity_name, _find_best_tab_match
from services.rule_engine import compare_columns


def run_comparison(model_name: str, stm_path: Path, sql_dir: Path, macros_dir: Path) -> dict:
    """Run full comparison for a single model."""
    stm_tabs = parse_stm_workbook(stm_path)
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

    parsed_sql = parse_sql_file(sql_path)
    dbt_columns = parsed_sql["columns"]
    jinja_metadata = parsed_sql["jinja_metadata"]

    detailed_results = compare_columns(stm_columns, dbt_columns, jinja_metadata)

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

    stm_rows = [r for r in detailed if r.get("stm_column")]
    matched = sum(1 for r in stm_rows if r.get("status", r["datatype_comparison"]) == "MATCH")
    mismatched = sum(1 for r in stm_rows if r.get("status", r["datatype_comparison"]) == "MISMATCH")
    missing_in_dbt = sum(1 for r in detailed if "missing in dbt" in (r.get("column_logic") or "").lower())
    extra_in_dbt = sum(1 for r in detailed if "not in stm" in (r.get("column_logic") or "").lower())

    total_compared = matched + mismatched
    match_rate = f"{(matched / total_compared * 100):.1f}%" if total_compared > 0 else "0%"

    transformation_counts = {}
    for r in detailed:
        t = r.get("transformation_logic", "Unknown")
        transformation_counts[t] = transformation_counts.get(t, 0) + 1

    return {
        "total_stm_columns": total_stm,
        "total_dbt_columns": total_dbt,
        "matched_columns": matched,
        "missing_in_dbt": missing_in_dbt,
        "extra_in_dbt": extra_in_dbt,
        "match_rate": match_rate,
        "datatype_matches": matched,
        "datatype_mismatches": mismatched,
        "transformation_types": transformation_counts,
    }
