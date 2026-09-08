import re

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

STM_RULE_TO_CLEANSING = {
    "general rule 1": "varchar_singlespace",
    "general rule 2": "varchar_question",
    "general rule 3": "varchar_na",
    "general rule 4": None,
    "general rule 5": None,
    "general rule 6": "varchar_na_lowercase",
    "general date rule 1": "date_low",
    "general date rule 2": "date_high",
    "general date rule 3": "timestamp_ntz_low",
    "general date rule 4": "timestamp_ntz_high",
    "general date rule 5": None,
    "general number rule 1": "numeric_zero",
    "general number rule 2": None,
    "general number rule 3": None,
    "general number rule 4": None,
    "general flag rule 1": "varchar_flag_y_n_u",
    "general flag rule 2": "varchar_flag_unknown",
    "general foreign key rule 1": "varchar_nokey",
    "general primary key rule 1": "varchar_nokey",
    "general source system rule 1": "varchar_question",
}

NOOP_RULES = {"general rule 5", "general date rule 5", "general number rule 4"}

RARE_RULE_KEYWORDS = {
    "general rule 4": ["trim", "@error"],
    "general number rule 2": ["null", "1"],
    "general number rule 3": ["numeric", "0"],
}

CLEANSING_DISPLAY = {
    "varchar_singlespace": "General Rule 1 (trim, default ' ')",
    "varchar_question": "General Rule 2 (trim, default '?')",
    "varchar_na": "General Rule 3 (trim, default 'NOT AVAILABLE')",
    "varchar_na_lowercase": "General Rule 6 (default 'N/A')",
    "varchar_nokey": "Foreign Key Rule (trim, default 'NOKEY')",
    "varchar_flag_unknown": "Flag Rule 2 (default 'U')",
    "varchar_flag_y_n_u": "Flag Rule 1 (Y/N/U conversion)",
    "numeric_zero": "Number Rule 1 (default 0)",
    "date_low": "Date Rule 1 (default 1900-01-01)",
    "date_high": "Date Rule 2 (default 9000-12-31)",
    "timestamp_ntz_low": "Timestamp Rule (default 1900-01-01)",
    "timestamp_ntz_high": "Timestamp Rule (default 9000-12-31)",
}


def _normalize_stm_name(name: str) -> str:
    name = re.sub(r"\s*\(PK\)\s*", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\s*\(FK\)\s*", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\s*\(.*?\)\s*$", "", name)
    name = name.strip().upper()
    name = re.sub(r"\s+", "_", name)
    return name


def compare_columns(stm_columns: list, dbt_columns: list, jinja_metadata: dict,
                    compiled_expressions: dict = None, dbt_source_expressions: dict = None,
                    cleansing_col_types: dict = None) -> list:
    if compiled_expressions is None:
        compiled_expressions = {}
    if dbt_source_expressions is None:
        dbt_source_expressions = {}
    if cleansing_col_types is None:
        cleansing_col_types = {}

    results = []
    dbt_col_map = {c["column_name"].upper(): c for c in dbt_columns}
    matched_dbt = set()
    cleansing_map = _build_cleansing_map(jinja_metadata)

    unmatched_stm = []
    for stm_col in stm_columns:
        stm_name = _normalize_stm_name(stm_col["target_column"])
        dbt_col = dbt_col_map.get(stm_name)
        if dbt_col:
            matched_dbt.add(stm_name)
            result = _compare_single_column(stm_col, dbt_col, cleansing_map,
                                            compiled_expressions, dbt_source_expressions, cleansing_col_types)
            results.append(result)
        else:
            unmatched_stm.append(stm_col)

    unmatched_dbt = [dbt_col for name, dbt_col in dbt_col_map.items() if name not in matched_dbt]
    resolved_stm, resolved_dbt = _cross_check_by_expression(
        unmatched_stm, unmatched_dbt, cleansing_map, compiled_expressions, dbt_source_expressions, cleansing_col_types)
    results.extend(resolved_stm)
    results.extend(resolved_dbt)
    return results


def _compare_single_column(stm_col, dbt_col, cleansing_map, compiled_expressions, dbt_source_expressions, cleansing_col_types):
    stm_type = _normalize_type(stm_col.get("data_type", ""))
    dbt_type = dbt_col.get("datatype", "-")
    expression = dbt_col.get("expression", "")
    col_name = dbt_col.get("column_name", "").upper()

    if dbt_type == "-" and cleansing_map and col_name in cleansing_map:
        dbt_type = cleansing_map[col_name]
    if dbt_type == "-":
        dbt_type = _infer_type_from_expression(expression)
    if dbt_type in ("NULL", "-") and re.match(r"^null(\s+as\s+\w+)?$", expression.strip(), re.IGNORECASE):
        dbt_type = "NULL"

    datatype_comparison = _compare_datatypes(stm_type, dbt_type)
    column_name_compare = _compare_column_names(stm_col["target_column"], dbt_col["column_name"])
    stm_scd = stm_col.get("scd_type", "")
    dbt_scd = dbt_col.get("scd_type", "")
    scd_comparison = _compare_scd_types(stm_scd, dbt_scd)

    stm_logic = _build_stm_logic(stm_col)
    dbt_biz_expr = dbt_source_expressions.get(col_name, "-") or "-"
    dbt_business_logic = dbt_biz_expr
    dbt_cleansing_rule = _get_cleansing_display(col_name, cleansing_col_types, compiled_expressions.get(col_name, ""))

    biz_result = _compare_business_logic(stm_col, dbt_biz_expr)
    rule_result = _compare_cleansing_rule(stm_col, col_name, cleansing_col_types, compiled_expressions.get(col_name, ""), dbt_biz_expr)

    if "MISMATCH" in biz_result or "MISMATCH" in rule_result:
        logic_comparison = "MISMATCH"
    elif "alias differs" in biz_result:
        logic_comparison = biz_result
    else:
        logic_comparison = "MATCH"

    has_mismatch = ("MISMATCH" in column_name_compare or datatype_comparison == "MISMATCH"
                    or scd_comparison == "MISMATCH" or "MISMATCH" in logic_comparison)
    overall_status = "MISMATCH" if has_mismatch else "MATCH"
    suggestion = "Reverify" if has_mismatch else "No action required"

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
        "stm_logic": stm_logic,
        "dbt_business_logic": dbt_business_logic,
        "dbt_cleansing_rule": dbt_cleansing_rule,
        "logic_comparison": logic_comparison,
        "suggestion": suggestion,
        "status": overall_status,
    }


# --- Business Logic Check (source columns in business mapping CTE) ---

def _compare_business_logic(stm_col, dbt_source_expr):
    if not dbt_source_expr or dbt_source_expr == "-":
        return "MISMATCH"

    stm_source = stm_col.get("source_column", "").strip()
    # Strip SQL comments
    stm_source = re.sub(r"--.*$", "", stm_source, flags=re.MULTILINE).strip()
    dbt_lower = dbt_source_expr.lower()
    target_col = _normalize_stm_name(stm_col.get("target_column", ""))

    if not stm_source:
        return "MISMATCH"

    # NULL source
    if re.match(r"^[,\s]*null\s+as\s+", stm_source.lower()):
        if "null" in dbt_lower or dbt_source_expr.strip().upper() == target_col:
            return "MATCH"
        return "MISMATCH"

    # CASE order check
    if re.search(r"\bcase\b", stm_source, re.IGNORECASE):
        return _compare_case_order(stm_source, dbt_source_expr)

    # COALESCE order check
    if re.search(r"\bcoalesce\b", stm_source, re.IGNORECASE):
        return _compare_coalesce_order(stm_source, dbt_source_expr)

    # table.column references
    stm_col_refs = re.findall(r"(\w+)\.(\w+)", stm_source)
    if stm_col_refs:
        dbt_col_refs = re.findall(r"(\w+)\.(\w+)", dbt_source_expr)
        alias_diffs = []
        for stm_tbl, stm_colname in stm_col_refs:
            if stm_colname.upper() == target_col:
                continue
            found = False
            for dbt_tbl, dbt_colname in dbt_col_refs:
                if stm_colname.upper() == dbt_colname.upper():
                    found = True
                    if stm_tbl.lower() != dbt_tbl.lower():
                        alias_diffs.append(f"{stm_tbl} → {dbt_tbl}")
                    break
            if not found:
                if stm_colname.lower() in dbt_lower:
                    found = True
            if not found:
                return "MISMATCH"
        if alias_diffs:
            return f"MATCH (alias differs: {', '.join(alias_diffs)})"
        return "MATCH"

    # @variables
    if "@" in stm_source:
        transformation = stm_col.get("transformation", "")
        var_values = _resolve_stm_variables(stm_source, transformation)
        if var_values:
            if all(val.lower() in dbt_lower for val in var_values):
                return "MATCH"
        if target_col and target_col.lower() in dbt_lower:
            return "MATCH"
        return "MISMATCH"

    return "MISMATCH"


def _compare_case_order(stm_source, dbt_source_expr):
    stm_cols = _extract_case_column_order(stm_source)
    dbt_cols = _extract_case_column_order(dbt_source_expr)

    if not stm_cols or not dbt_cols:
        stm_refs = [c.upper() for _, c in re.findall(r"(\w+)\.(\w+)", stm_source)]
        dbt_lower = dbt_source_expr.lower()
        if stm_refs and all(c.lower() in dbt_lower for c in stm_refs):
            return "MATCH"
        return "MISMATCH"

    if stm_cols == dbt_cols:
        return "MATCH"

    if set(stm_cols) == set(dbt_cols):
        return "MISMATCH"

    return "MISMATCH"


def _extract_case_column_order(expr):
    whens = re.findall(r"when\b[^.]*?(\w+)\.(\w+)", expr, re.IGNORECASE)
    return [col.upper() for _, col in whens]


def _compare_coalesce_order(stm_source, dbt_source_expr):
    stm_args = _extract_coalesce_args(stm_source)
    dbt_args = _extract_coalesce_args(dbt_source_expr)

    if not stm_args or not dbt_args:
        return "MATCH"

    if stm_args == dbt_args:
        return "MATCH"

    if set(stm_args) == set(dbt_args):
        return "MISMATCH"

    return "MISMATCH"


def _extract_coalesce_args(expr):
    match = re.search(r"coalesce\s*\(([^)]+)\)", expr, re.IGNORECASE)
    if not match:
        return []
    args_str = match.group(1)
    cols = []
    for arg in args_str.split(","):
        col_match = re.search(r"(\w+)\.(\w+)", arg.strip())
        if col_match:
            cols.append(col_match.group(2).upper())
        else:
            clean = re.sub(r"cast\s*\(", "", arg.strip(), flags=re.IGNORECASE)
            clean = re.sub(r"\s+as\s+\w+.*", "", clean, flags=re.IGNORECASE).strip()
            if clean:
                cols.append(clean.upper())
    return cols


# --- Cleansing Rule Check ---

INLINE_FLAG_CHECKS = {
    "general flag rule 1": {"must_have": ["'y'", "'n'", "'u'"]},
    "general flag rule 2": {"must_have": ["'u'"]},
}

def _compare_cleansing_rule(stm_col, col_name, cleansing_col_types, compiled_expr, dbt_biz_expr=""):
    business_rule = stm_col.get("business_rule", "").strip().lower()
    stm_source = stm_col.get("source_column", "").strip()

    if not business_rule:
        return "MISMATCH"

    # No-op rules
    if business_rule in NOOP_RULES:
        return "MATCH"

    # NULL source with active rule
    if re.match(r"^[,\s]*null\s+as\s+", stm_source.lower()):
        expected_type = STM_RULE_TO_CLEANSING.get(business_rule)
        actual_type = cleansing_col_types.get(col_name)
        if expected_type and actual_type:
            return "MATCH" if expected_type == actual_type else "MISMATCH"
        if actual_type is None:
            return _check_inline_logic(business_rule, compiled_expr, dbt_biz_expr)
        return "MISMATCH"

    # Standard rules — first check if m_cleansing macro is applied
    expected_type = STM_RULE_TO_CLEANSING.get(business_rule)
    actual_type = cleansing_col_types.get(col_name)

    if expected_type is not None and actual_type is not None:
        return "MATCH" if expected_type == actual_type else "MISMATCH"

    # No macro applied — check inline logic in business mapping or compiled expression
    if actual_type is None:
        return _check_inline_logic(business_rule, compiled_expr, dbt_biz_expr)

    return "MISMATCH"


def _check_inline_logic(business_rule, compiled_expr, dbt_biz_expr=""):
    """When no m_cleansing macro is applied, check the inline CASE/logic."""
    # Check both business mapping expression and compiled expression
    check_text = ((dbt_biz_expr or "") + " " + (compiled_expr or "")).lower()
    if not check_text.strip():
        return "MISMATCH"

    compiled_lower = check_text

    # Flag rules — check inline CASE for correct Y/N/U values
    if business_rule in INLINE_FLAG_CHECKS:
        check = INLINE_FLAG_CHECKS[business_rule]
        if all(kw in compiled_lower for kw in check["must_have"]):
            return "MATCH"
        return "MISMATCH"

    # Rare rules — keyword check
    if business_rule in RARE_RULE_KEYWORDS:
        keywords = RARE_RULE_KEYWORDS[business_rule]
        if all(kw.lower() in compiled_lower for kw in keywords):
            return "MATCH"
        return "MISMATCH"

    # For standard rules without macro, check if compiled expression has expected behavior
    expected_type = STM_RULE_TO_CLEANSING.get(business_rule)
    if expected_type:
        display = CLEANSING_DISPLAY.get(expected_type, "")
        # Extract the default value from display label and check in compiled
        default_match = re.search(r"default\s+'([^']*)'", display)
        if default_match:
            default_val = default_match.group(1).lower()
            if default_val in compiled_lower:
                return "MATCH"
    return "MISMATCH"


def _get_cleansing_display(col_name, cleansing_col_types, compiled_expr=""):
    actual_type = cleansing_col_types.get(col_name)
    if actual_type:
        return CLEANSING_DISPLAY.get(actual_type, actual_type)
    # No macro — show actual compiled expression from cleansing CTE
    if compiled_expr and compiled_expr != "-":
        return f"No macro: {compiled_expr}"
    return "No cleansing applied"


# --- Cross-check unmatched columns ---

def _cross_check_by_expression(unmatched_stm, unmatched_dbt, cleansing_map,
                               compiled_expressions, dbt_source_expressions, cleansing_col_types):
    resolved_stm = []
    resolved_dbt = []
    matched_indices = set()

    for stm_col in unmatched_stm:
        stm_source = stm_col.get("source_column", "").upper().strip()
        found = False
        if stm_source:
            for i, dbt_col in enumerate(unmatched_dbt):
                if i in matched_indices:
                    continue
                dbt_expr = dbt_col.get("expression", "")
                dbt_src = _extract_source_col_from_expr(dbt_expr)
                if dbt_src and stm_source == dbt_src.upper():
                    matched_indices.add(i)
                    result = _name_mismatch_result(stm_col, dbt_col, cleansing_map,
                                                   compiled_expressions, dbt_source_expressions, cleansing_col_types)
                    resolved_stm.append(result)
                    found = True
                    break
        if not found:
            resolved_stm.append(_missing_in_dbt(stm_col))

    for i, dbt_col in enumerate(unmatched_dbt):
        if i not in matched_indices:
            resolved_dbt.append(_extra_in_dbt(dbt_col, compiled_expressions, dbt_source_expressions, cleansing_col_types))

    return resolved_stm, resolved_dbt


def _name_mismatch_result(stm_col, dbt_col, cleansing_map, compiled_expressions, dbt_source_expressions, cleansing_col_types):
    stm_type = _normalize_type(stm_col.get("data_type", ""))
    dbt_type = dbt_col.get("datatype", "-")
    expression = dbt_col.get("expression", "")
    col_name = dbt_col.get("column_name", "").upper()

    if dbt_type == "-" and cleansing_map and col_name in cleansing_map:
        dbt_type = cleansing_map[col_name]
    if dbt_type == "-":
        dbt_type = _infer_type_from_expression(expression)
    if dbt_type in ("NULL", "-") and re.match(r"^null(\s+as\s+\w+)?$", expression.strip(), re.IGNORECASE):
        dbt_type = "NULL"

    stm_logic = _build_stm_logic(stm_col)
    dbt_biz_expr = dbt_source_expressions.get(col_name, "-") or "-"
    dbt_business_logic = dbt_biz_expr
    dbt_cleansing_rule = _get_cleansing_display(col_name, cleansing_col_types, compiled_expressions.get(col_name, "") if compiled_expressions else "")

    return {
        "stm_column": stm_col["target_column"],
        "dbt_column": dbt_col["column_name"],
        "column_name_compare": f"NAME MISMATCH (same expression: {_extract_source_col_from_expr(expression)})",
        "stm_datatype": stm_col.get("data_type", ""),
        "dbt_datatype": dbt_type,
        "datatype_comparison": _compare_datatypes(stm_type, dbt_type),
        "stm_scd_type": stm_col.get("scd_type", ""),
        "dbt_scd_type": dbt_col.get("scd_type", ""),
        "scd_comparison": _compare_scd_types(stm_col.get("scd_type", ""), dbt_col.get("scd_type", "")),
        "stm_logic": stm_logic,
        "dbt_business_logic": dbt_business_logic,
        "dbt_cleansing_rule": dbt_cleansing_rule,
        "logic_comparison": "MISMATCH",
        "suggestion": "Reverify",
        "status": "MISMATCH",
    }


def _missing_in_dbt(stm_col):
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
        "stm_logic": _build_stm_logic(stm_col),
        "dbt_business_logic": "-",
        "dbt_cleansing_rule": "-",
        "logic_comparison": "MISMATCH",
        "suggestion": "Reverify",
        "status": "MISMATCH",
    }


def _extra_in_dbt(dbt_col, compiled_expressions, dbt_source_expressions, cleansing_col_types):
    col_name = dbt_col.get("column_name", "").upper()
    dbt_biz_expr = dbt_source_expressions.get(col_name, "-") or "-"
    return {
        "stm_column": "-",
        "dbt_column": dbt_col["column_name"],
        "column_name_compare": "NOT FOUND in STM",
        "stm_datatype": "-",
        "dbt_datatype": dbt_col.get("datatype", "-"),
        "datatype_comparison": "MISMATCH",
        "stm_scd_type": "-",
        "dbt_scd_type": dbt_col.get("scd_type", ""),
        "scd_comparison": "MISMATCH",
        "stm_logic": "-",
        "dbt_business_logic": dbt_biz_expr,
        "dbt_cleansing_rule": _get_cleansing_display(col_name, cleansing_col_types, compiled_expressions.get(col_name, "") if compiled_expressions else ""),
        "logic_comparison": "MISMATCH",
        "suggestion": "Reverify",
        "status": "MISMATCH",
    }


# --- Helpers ---

def _build_stm_logic(stm_col):
    parts = []
    source_column = stm_col.get("source_column", "").strip()
    business_rule = stm_col.get("business_rule", "").strip()
    # Strip SQL comments from source column
    source_column = re.sub(r"--.*$", "", source_column, flags=re.MULTILINE).strip()
    if source_column:
        parts.append(source_column)
    if business_rule:
        parts.append(business_rule)
    return " | ".join(parts) if parts else "-"


def _extract_source_col_from_expr(expression):
    expr = expression.strip()
    expr = re.sub(r"\s+AS\s+\w+\s*$", "", expr, flags=re.IGNORECASE)
    match = re.match(r"^(\w+)\.(\w+)$", expr)
    if match:
        return match.group(2).upper()
    match = re.match(r"^(\w+)$", expr)
    if match:
        return match.group(1).upper()
    return ""


def _resolve_stm_variables(stm_source, transformation):
    var_refs = re.findall(r"@(\w+)", stm_source)
    if not var_refs:
        return []
    declares = {}
    for match in re.finditer(r"declare\s+@(\w+)\s+\w+(?:\([^)]*\))?\s*=\s*'([^']*)'", transformation, re.IGNORECASE):
        declares[match.group(1).upper()] = match.group(2)
    return [declares[v.upper()] for v in var_refs if v.upper() in declares]


def _build_cleansing_map(jinja_metadata):
    col_type_map = {}
    for entry in jinja_metadata.get("macros_used", {}).get("m_cleansing", []):
        if ":" in entry:
            ctype, cname = entry.split(":", 1)
            col_type_map[cname.upper().strip()] = CLEANSING_TYPE_MAP.get(ctype.lower().strip(), "VARCHAR")
    return col_type_map


def _get_compiled_expression(col_name, compiled_expressions):
    expr = compiled_expressions.get(col_name.upper(), "-")
    if expr and len(expr) > 500:
        return expr[:497] + "..."
    return expr or "-"


def _compare_column_names(stm_name, dbt_name):
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


def _compare_scd_types(stm_scd, dbt_scd):
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


def _normalize_type(dtype):
    if not dtype:
        return ""
    return re.sub(r"\s+", "", dtype.strip().lower())


def _compare_datatypes(stm_type, dbt_type):
    if dbt_type == "NULL":
        return "MISMATCH"
    if not stm_type and not dbt_type:
        return "MATCH"
    if dbt_type in ("-", ""):
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
    for _, aliases in type_aliases.items():
        if stm_base in aliases and dbt_base in aliases:
            return "MATCH"
    return "MISMATCH"


def _infer_type_from_expression(expression):
    if not expression:
        return "-"
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
    return "-"
