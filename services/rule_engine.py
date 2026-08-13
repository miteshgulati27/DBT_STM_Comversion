import re

MACRO_BUSINESS_RULES = {
    "m_cleanse_string": "Direct Pass-through",
    "m_cleanse_number": "Direct Pass-through",
    "m_cleanse_flag": "Direct Pass-through",
    "m_cleanse_primary_key": "Direct Pass-through",
    "m_cleanse_foreign_key": "Direct Pass-through",
    "m_cleanse_source_system": "Direct Pass-through",
    "m_cleanse_date": "Direct Pass-through",
}

CLEANSING_TYPE_MAP = {
    "varchar_nokey": "VARCHAR",
    "varchar_question": "VARCHAR",
    "varchar_singlespace": "VARCHAR",
    "varchar_na": "VARCHAR",
    "varchar_na_lowercase": "VARCHAR",
    "varchar_flag_unknown": "VARCHAR",
    "varchar_flag_y_n_u": "VARCHAR",
    "numeric_zero": "NUMBER",
    "date_low": "DATE",
    "date_high": "DATE",
    "timestamp_ntz_low": "TIMESTAMP_NTZ",
    "timestamp_ntz_high": "TIMESTAMP_NTZ",
}


def _normalize_stm_name(name: str) -> str:
    """Strip (PK), (FK), replace spaces with underscores for matching."""
    name = re.sub(r"\s*\(PK\)\s*", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\s*\(FK\)\s*", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\s*\(.*?\)\s*$", "", name)
    name = name.strip().upper()
    name = re.sub(r"\s+", "_", name)
    return name


def compare_columns(stm_columns: list, dbt_columns: list, jinja_metadata: dict) -> list:
    """Compare STM columns against DBT columns using rule-based matching."""
    results = []
    dbt_col_map = {c["column_name"].upper(): c for c in dbt_columns}
    matched_dbt = set()

    cleansing_map = _build_cleansing_map(jinja_metadata)

    unmatched_stm = []
    for stm_col in stm_columns:
        stm_raw_name = stm_col["target_column"]
        stm_name = _normalize_stm_name(stm_raw_name)
        dbt_col = dbt_col_map.get(stm_name)

        if dbt_col:
            matched_dbt.add(stm_name)
            result = _compare_single_column(stm_col, dbt_col, jinja_metadata, cleansing_map)
            results.append(result)
        else:
            unmatched_stm.append(stm_col)

    unmatched_dbt = []
    for dbt_name, dbt_col in dbt_col_map.items():
        if dbt_name not in matched_dbt:
            unmatched_dbt.append(dbt_col)

    resolved_stm, resolved_dbt = _cross_check_by_expression(unmatched_stm, unmatched_dbt, jinja_metadata, cleansing_map)

    for result in resolved_stm:
        results.append(result)
    for result in resolved_dbt:
        results.append(result)

    return results


def _cross_check_by_expression(unmatched_stm: list, unmatched_dbt: list, jinja_metadata: dict, cleansing_map: dict) -> tuple:
    """Cross-check unmatched columns by expression. If expressions match but names differ, flag as NAME MISMATCH."""
    resolved_stm_results = []
    resolved_dbt_results = []
    matched_dbt_indices = set()

    for stm_col in unmatched_stm:
        stm_source = stm_col.get("source_column", "").upper().strip()
        found = False

        if stm_source:
            for i, dbt_col in enumerate(unmatched_dbt):
                if i in matched_dbt_indices:
                    continue
                dbt_expr = dbt_col.get("expression", "")
                dbt_expr_source = _extract_source_col_from_expr(dbt_expr)

                if dbt_expr_source and stm_source == dbt_expr_source.upper():
                    matched_dbt_indices.add(i)
                    result = _name_mismatch_result(stm_col, dbt_col, jinja_metadata, cleansing_map)
                    resolved_stm_results.append(result)
                    found = True
                    break

        if not found:
            resolved_stm_results.append(_missing_in_dbt(stm_col))

    for i, dbt_col in enumerate(unmatched_dbt):
        if i not in matched_dbt_indices:
            resolved_dbt_results.append(_extra_in_dbt(dbt_col))

    return resolved_stm_results, resolved_dbt_results


def _extract_source_col_from_expr(expression: str) -> str:
    """Extract the source column reference from a DBT expression (e.g., 'capp.CA7VIN' -> 'CA7VIN')."""
    expr = expression.strip()
    expr = re.sub(r"\s+AS\s+\w+\s*$", "", expr, flags=re.IGNORECASE)

    match = re.match(r"^(\w+)\.(\w+)$", expr)
    if match:
        return match.group(2).upper()

    match = re.match(r"^(\w+)$", expr)
    if match:
        return match.group(1).upper()

    return ""


def _name_mismatch_result(stm_col: dict, dbt_col: dict, jinja_metadata: dict, cleansing_map: dict) -> dict:
    """Build result for columns with same expression but different names."""
    stm_type = _normalize_type(stm_col.get("data_type", ""))
    dbt_type = dbt_col.get("datatype", "UNKNOWN")
    expression = dbt_col.get("expression", "")
    col_name = dbt_col.get("column_name", "").upper()

    if dbt_type == "UNKNOWN" and cleansing_map and col_name in cleansing_map:
        dbt_type = cleansing_map[col_name]
    if dbt_type == "UNKNOWN":
        dbt_type = _infer_type_from_expression(expression)
    if dbt_type in ("NULL", "UNKNOWN") and re.match(r"^null(\s+as\s+\w+)?$", expression.strip(), re.IGNORECASE):
        dbt_type = "NULL"

    datatype_comparison = _compare_datatypes(stm_type, dbt_type)

    return {
        "stm_column": stm_col["target_column"],
        "dbt_column": dbt_col["column_name"],
        "column_name_compare": f"NAME MISMATCH (same expression: {_extract_source_col_from_expr(expression)})",
        "stm_datatype": stm_col.get("data_type", ""),
        "dbt_datatype": dbt_type,
        "datatype_comparison": datatype_comparison,
        "stm_scd_type": stm_col.get("scd_type", ""),
        "dbt_scd_type": dbt_col.get("scd_type", ""),
        "scd_comparison": _compare_scd_types(stm_col.get("scd_type", ""), dbt_col.get("scd_type", "")),
        "column_logic": "Mapped as per STM (renamed)",
        "transformation_logic": _detect_transformation(expression, jinja_metadata),
        "source_expression": _build_source_expression(expression, dbt_col),
        "suggestion": "Review - column name differs between STM and DBT",
        "status": "MISMATCH",
    }


def _build_cleansing_map(jinja_metadata: dict) -> dict:
    """Build column_name -> inferred_type map from m_cleansing macro usage."""
    col_type_map = {}
    macros_used = jinja_metadata.get("macros_used", {})

    for entry in macros_used.get("m_cleansing", []):
        if ":" in entry:
            cleansing_type, col_name = entry.split(":", 1)
            inferred_type = CLEANSING_TYPE_MAP.get(cleansing_type.lower().strip(), "VARCHAR")
            col_type_map[col_name.upper().strip()] = inferred_type

    return col_type_map


def _compare_single_column(stm_col: dict, dbt_col: dict, jinja_metadata: dict, cleansing_map: dict = None) -> dict:
    """Compare a matched STM-DBT column pair."""
    stm_type = _normalize_type(stm_col.get("data_type", ""))
    dbt_type = dbt_col.get("datatype", "UNKNOWN")
    expression = dbt_col.get("expression", "")
    col_name = dbt_col.get("column_name", "").upper()

    if dbt_type == "UNKNOWN" and cleansing_map and col_name in cleansing_map:
        dbt_type = cleansing_map[col_name]

    if dbt_type == "UNKNOWN":
        dbt_type = _infer_type_from_expression(expression)

    if dbt_type in ("NULL", "UNKNOWN") and re.match(r"^null(\s+as\s+\w+)?$", expression.strip(), re.IGNORECASE):
        dbt_type = "NULL"

    datatype_comparison = _compare_datatypes(stm_type, dbt_type)
    transformation_logic = _detect_transformation(expression, jinja_metadata)
    source_expression = _build_source_expression(expression, dbt_col)
    column_logic = _determine_column_logic(stm_col, dbt_col, expression)
    suggestion = _generate_suggestion(datatype_comparison, column_logic, transformation_logic)

    column_name_compare = _compare_column_names(stm_col["target_column"], dbt_col["column_name"])

    if "MISMATCH" in column_name_compare:
        suggestion = "Review - column name mismatch: " + column_name_compare

    stm_scd = stm_col.get("scd_type", "")
    dbt_scd = dbt_col.get("scd_type", "")
    scd_comparison = _compare_scd_types(stm_scd, dbt_scd)

    overall_status = "MISMATCH" if ("MISMATCH" in column_name_compare or datatype_comparison == "MISMATCH" or scd_comparison == "MISMATCH") else "MATCH"

    if scd_comparison == "MISMATCH" and "MISMATCH" not in column_name_compare and datatype_comparison != "MISMATCH":
        suggestion = f"Review - SCD type mismatch: STM={stm_scd or '-'} vs DBT={dbt_scd or '-'}"

    return {
        "stm_column": stm_col["target_column"],
        "dbt_column": dbt_col["column_name"],
        "column_name_compare": column_name_compare,
        "stm_datatype": stm_col.get("data_type", ""),
        "dbt_datatype": dbt_type,
        "datatype_comparison": datatype_comparison,
        "stm_scd_type": stm_scd,
        "dbt_scd_type": dbt_scd,
        "scd_comparison": scd_comparison,
        "column_logic": column_logic,
        "transformation_logic": transformation_logic,
        "source_expression": source_expression,
        "suggestion": suggestion,
        "status": overall_status,
    }


def _compare_column_names(stm_name: str, dbt_name: str) -> str:
    """Compare STM and DBT column names and explain the relationship."""
    stm_clean = _normalize_stm_name(stm_name)
    dbt_clean = dbt_name.upper().strip()

    if stm_clean == dbt_clean:
        raw_stm = stm_name.strip().upper()
        raw_dbt = dbt_name.strip().upper()
        if raw_stm == raw_dbt:
            return "MATCH"
        if "(PK)" in stm_name.upper():
            return "MATCH (STM has (PK) suffix)"
        if "(FK)" in stm_name.upper():
            return "MATCH (STM has (FK) suffix)"
        if " " in stm_name.strip() and "_" in dbt_name:
            return "MISMATCH (space vs underscore in STM)"
        return "MATCH (normalized)"

    if stm_clean.replace("_", "") == dbt_clean.replace("_", ""):
        return "MATCH (underscore difference)"

    return f"MISMATCH (STM: {stm_name} vs DBT: {dbt_name})"


def _compare_scd_types(stm_scd: str, dbt_scd: str) -> str:
    """Compare SCD types between STM and DBT."""
    if not stm_scd and not dbt_scd:
        return "MATCH"
    if not stm_scd or not dbt_scd:
        return "MATCH"
    stm_norm = stm_scd.strip().upper()
    dbt_norm = dbt_scd.strip().upper()
    if stm_norm == dbt_norm:
        return "MATCH"
    if stm_norm in ("N/A", "KEY", "PK") and dbt_norm == "N/A":
        return "MATCH"
    return "MISMATCH"


def _missing_in_dbt(stm_col: dict) -> dict:
    return {
        "stm_column": stm_col["target_column"],
        "dbt_column": "-",
        "column_name_compare": "NOT FOUND in DBT",
        "stm_datatype": stm_col.get("data_type", ""),
        "dbt_datatype": "-",
        "datatype_comparison": "MISMATCH",
        "stm_scd_type": stm_col.get("scd_type", ""),
        "dbt_scd_type": "-",
        "scd_comparison": "MISMATCH",
        "column_logic": "Column missing in DBT",
        "transformation_logic": "-",
        "source_expression": "-",
        "suggestion": "Review - column not found in DBT model",
        "status": "MISMATCH",
    }


def _extra_in_dbt(dbt_col: dict) -> dict:
    return {
        "stm_column": "-",
        "dbt_column": dbt_col["column_name"],
        "column_name_compare": "NOT FOUND in STM",
        "stm_datatype": "-",
        "dbt_datatype": dbt_col.get("datatype", "UNKNOWN"),
        "datatype_comparison": "MISMATCH",
        "stm_scd_type": "-",
        "dbt_scd_type": dbt_col.get("scd_type", ""),
        "scd_comparison": "MISMATCH",
        "column_logic": "Extra column not in STM",
        "transformation_logic": _detect_transformation(dbt_col.get("expression", ""), {}),
        "source_expression": _build_source_expression(dbt_col.get("expression", ""), dbt_col),
        "suggestion": "Review - column exists in DBT but not documented in STM",
        "status": "MISMATCH",
    }


def _normalize_type(dtype: str) -> str:
    if not dtype:
        return ""
    dtype = dtype.strip().lower()
    dtype = re.sub(r"\s+", "", dtype)
    return dtype




def _compare_datatypes(stm_type: str, dbt_type: str) -> str:
    if dbt_type == "NULL":
        return "MISMATCH"
    if not stm_type and not dbt_type:
        return "MATCH"
    if dbt_type in ("UNKNOWN", ""):
        return "MISMATCH"
    if not stm_type:
        return "MATCH"

    stm_norm = stm_type.lower().replace(" ", "")
    dbt_norm = dbt_type.lower().replace(" ", "")

    if stm_norm == dbt_norm:
        return "MATCH"

    stm_base = re.sub(r"\(.*\)", "", stm_norm)
    dbt_base = re.sub(r"\(.*\)", "", dbt_norm)

    type_aliases = {
        "varchar": ["varchar", "string", "text", "char"],
        "int": ["int", "integer", "bigint", "smallint", "number"],
        "decimal": ["decimal", "numeric", "number", "float", "double"],
        "date": ["date", "timestamp", "datetime"],
        "boolean": ["boolean", "bool"],
    }

    for canonical, aliases in type_aliases.items():
        if stm_base in aliases and dbt_base in aliases:
            return "MATCH"

    return "MISMATCH"


def _detect_transformation(expression: str, jinja_metadata: dict) -> str:
    if not expression:
        return "Unknown"

    expr_lower = expression.lower().strip()

    if expr_lower == "null" or expr_lower.startswith("null"):
        return "NULL Placeholder"

    macros_used = jinja_metadata.get("macros_used", {}) if jinja_metadata else {}
    for macro_name in macros_used:
        if macro_name in MACRO_BUSINESS_RULES:
            return MACRO_BUSINESS_RULES[macro_name]

    if re.search(r"\bcoalesce\s*\(", expr_lower):
        return "COALESCE"

    if re.search(r"\bcast\s*\(", expr_lower):
        return "Type Cast"

    if re.search(r"\bcase\s+", expr_lower):
        return "CASE Logic"

    if "||" in expression or re.search(r"\bconcat\s*\(", expr_lower):
        return "String Concatenation"

    if re.search(r"^\w+\.\w+$", expr_lower):
        return "Direct Pass-through"

    if re.search(r"\b(sum|count|avg|max|min)\s*\(", expr_lower):
        return "Mixed Operations"

    return "Direct Pass-through"


def _build_source_expression(expression: str, dbt_col: dict) -> str:
    if not expression:
        return "N/A"

    if re.match(r"^null(\s+as\s+\w+)?$", expression.strip(), re.IGNORECASE):
        return "NULL"

    if len(expression) > 150:
        return expression[:147] + "..."

    return expression


def _extract_inner_source_column(expression: str) -> str:
    """Extract the actual source column from cleansing wrappers like coalesce(nullif(ltrim(cast(src.X as varchar)),''),' ')."""
    match = re.search(r"(?:src|source|polper|job|capp|a|b)\.\w+", expression, re.IGNORECASE)
    if match:
        return match.group(0)

    match = re.search(r"cast\s*\(\s*(\w+\.\w+)", expression, re.IGNORECASE)
    if match:
        return match.group(1)

    return ""


def _detect_cleansing_rule(expression: str) -> str:
    """Detect which cleansing rule is applied from the expression pattern."""
    expr_lower = expression.lower()

    if re.search(r"coalesce\s*\(.*?,\s*'nokey'\s*\)", expr_lower):
        return "VARCHAR_NOKEY"
    if re.search(r"coalesce\s*\(.*?,\s*' '\s*\)", expr_lower):
        return "VARCHAR_SINGLESPACE"
    if re.search(r"coalesce\s*\(.*?,\s*'\?'\s*\)", expr_lower):
        return "VARCHAR_QUESTION"
    if re.search(r"coalesce\s*\(.*?,\s*0\s*\)", expr_lower):
        return "NUMERIC_ZERO"
    if "case.*then 'y'.*then 'n'" in expr_lower.replace('\n', ' '):
        return "VARCHAR_FLAG_Y_N_U"
    if re.search(r"case\s+when.*'y'.*'n'.*'u'", expr_lower, re.DOTALL):
        return "VARCHAR_FLAG_Y_N_U"

    return ""


def _determine_column_logic(stm_col: dict, dbt_col: dict, expression: str) -> str:
    expr_lower = expression.lower().strip() if expression else ""

    if re.match(r"^null(\s+as\s+\w+)?$", expr_lower):
        stm_transform = stm_col.get("transformation", "").lower()
        if "not applicable" in stm_transform or "n/a" in stm_transform:
            return f"Intentional NULL (Not applicable)"
        return "Intentional NULL"

    return "Mapped as per STM"


def _infer_type_from_expression(expression: str) -> str:
    """Infer datatype only from m_cleansing logic and SQL expression syntax. No column name guessing."""
    if not expression:
        return "UNKNOWN"

    expr_lower = expression.lower().strip()
    if re.match(r"^null(\s+as\s+\w+)?$", expr_lower):
        return "NULL"

    cast_match = re.search(r"cast\s*\(.*?\s+as\s+(\w+(?:\([^)]*\))?)\s*\)", expr_lower)
    if cast_match:
        return cast_match.group(1).upper()

    if "||" in expression or re.search(r"\bconcat\s*\(", expr_lower):
        return "VARCHAR"

    if re.match(r"^'[^']*'(\s+as\s+\w+)?$", expr_lower):
        return "VARCHAR"

    if re.search(r"\bcase\b.*\bthen\b\s*'", expr_lower, re.DOTALL):
        return "VARCHAR"
    if re.search(r"\bcase\b.*\bthen\b\s*\d", expr_lower, re.DOTALL):
        return "NUMBER"

    if re.search(r"\b(sum|count|avg)\s*\(", expr_lower):
        return "NUMBER"

    return "UNKNOWN"


def _generate_suggestion(datatype_comparison: str, column_logic: str, transformation: str) -> str:
    if datatype_comparison == "MATCH":
        return "No action required"

    if "missing in DBT" in column_logic.lower():
        return "Review - column not found in DBT model"

    if "not in STM" in column_logic.lower():
        return "Review - column exists in DBT but not documented in STM"

    if transformation == "NULL Placeholder":
        return "Review datatype compatibility"

    return "Review datatype compatibility"
