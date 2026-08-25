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

# Maps STM general rule names to expected DBT behavior patterns
# ALL keywords must appear in DBT compiled expression for a MATCH
GENERAL_RULE_PATTERNS = {
    "general rule 1": {"keywords": ["trim", "' '"]},
    "general rule 2": {"keywords": ["trim", "'?'"]},
    "general rule 3": {"keywords": ["trim", "not available"]},
    "general rule 4": {"keywords": ["trim", "@error"]},
    "general rule 5": {"keywords": ["trim", "null"]},
    "general rule 6": {"keywords": ["n/a"]},
    "general date rule 1": {"keywords": ["1900-01-01"]},
    "general date rule 2": {"keywords": ["9000-12-31"]},
    "general date rule 3": {"keywords": ["1900-01-01", "2079-06-06"]},
    "general date rule 4": {"keywords": ["1970-01-01", "2025-06-06"]},
    "general date rule 5": {"keywords": ["null"]},
    "general number rule 1": {"keywords": ["null", "0"]},
    "general number rule 2": {"keywords": ["null", "1"]},
    "general number rule 3": {"keywords": ["numeric", "0"]},
    "general number rule 4": {"keywords": ["null"]},
    "general flag rule 1": {"keywords": ["'u'"]},
    "general flag rule 2": {"keywords": ["'n'"]},
    "general foreign key rule 1": {"keywords": ["nokey"]},
    "general primary key rule 1": {"keywords": ["trim", "nokey"]},
    "general source system rule 1": {"keywords": ["trim", "'?'"]},
}


def _normalize_stm_name(name: str) -> str:
    """Strip (PK), (FK), replace spaces with underscores for matching."""
    name = re.sub(r"\s*\(PK\)\s*", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\s*\(FK\)\s*", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\s*\(.*?\)\s*$", "", name)
    name = name.strip().upper()
    name = re.sub(r"\s+", "_", name)
    return name


def compare_columns(stm_columns: list, dbt_columns: list, jinja_metadata: dict, compiled_expressions: dict = None) -> list:
    """Compare STM columns against DBT columns using rule-based matching."""
    if compiled_expressions is None:
        compiled_expressions = {}

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
            result = _compare_single_column(stm_col, dbt_col, jinja_metadata, cleansing_map, compiled_expressions)
            results.append(result)
        else:
            unmatched_stm.append(stm_col)

    unmatched_dbt = []
    for dbt_name, dbt_col in dbt_col_map.items():
        if dbt_name not in matched_dbt:
            unmatched_dbt.append(dbt_col)

    resolved_stm, resolved_dbt = _cross_check_by_expression(unmatched_stm, unmatched_dbt, jinja_metadata, cleansing_map, compiled_expressions)

    for result in resolved_stm:
        results.append(result)
    for result in resolved_dbt:
        results.append(result)

    return results


def _cross_check_by_expression(unmatched_stm: list, unmatched_dbt: list, jinja_metadata: dict, cleansing_map: dict, compiled_expressions: dict) -> tuple:
    """Cross-check unmatched columns by expression."""
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
                    result = _name_mismatch_result(stm_col, dbt_col, jinja_metadata, cleansing_map, compiled_expressions)
                    resolved_stm_results.append(result)
                    found = True
                    break

        if not found:
            resolved_stm_results.append(_missing_in_dbt(stm_col))

    for i, dbt_col in enumerate(unmatched_dbt):
        if i not in matched_dbt_indices:
            resolved_dbt_results.append(_extra_in_dbt(dbt_col, compiled_expressions))

    return resolved_stm_results, resolved_dbt_results


def _extract_source_col_from_expr(expression: str) -> str:
    """Extract the source column reference from a DBT expression."""
    expr = expression.strip()
    expr = re.sub(r"\s+AS\s+\w+\s*$", "", expr, flags=re.IGNORECASE)

    match = re.match(r"^(\w+)\.(\w+)$", expr)
    if match:
        return match.group(2).upper()

    match = re.match(r"^(\w+)$", expr)
    if match:
        return match.group(1).upper()

    return ""


def _build_stm_logic(stm_col: dict) -> str:
    """Build STM logic display: source_column | general rule applied."""
    parts = []
    source_column = stm_col.get("source_column", "").strip()
    business_rule = stm_col.get("business_rule", "").strip()

    if source_column:
        parts.append(source_column)
    if business_rule:
        parts.append(business_rule)

    return " | ".join(parts) if parts else "-"


def _resolve_stm_variables(stm_source: str, transformation: str) -> list:
    """Resolve @variables in STM source_column using declare statements in transformation field."""
    # Extract all @variable references from source
    var_refs = re.findall(r"@(\w+)", stm_source)
    if not var_refs:
        return []

    # Extract declare statements: declare @VAR type = 'value'
    declares = {}
    for match in re.finditer(r"declare\s+@(\w+)\s+\w+(?:\([^)]*\))?\s*=\s*'([^']*)'", transformation, re.IGNORECASE):
        declares[match.group(1).upper()] = match.group(2)

    # Resolve each variable to its value
    resolved = []
    for var in var_refs:
        value = declares.get(var.upper())
        if value:
            resolved.append(value)

    return resolved


def _get_compiled_expression(col_name: str, compiled_expressions: dict) -> str:
    """Get the compiled expression for a column, truncated for display if too long."""
    expr = compiled_expressions.get(col_name.upper(), "-")
    if expr and len(expr) > 500:
        return expr[:497] + "..."
    return expr or "-"


def _compare_logic(stm_col: dict, dbt_compiled_expr: str) -> str:
    """Compare STM logic vs DBT compiled expression (strict).

    Checks THREE things — ALL must pass:
    1. Source column: Does DBT reference the same source column(s) as STM?
    2. Cleansing rule: Does DBT apply ALL expected keywords from the general rule?
    3. NULL handling: If STM is intentionally NULL, DBT must also be NULL.
    """
    if not dbt_compiled_expr or dbt_compiled_expr == "-":
        return "MISMATCH"

    dbt_lower = dbt_compiled_expr.lower()
    stm_source = stm_col.get("source_column", "").strip()
    business_rule = stm_col.get("business_rule", "").strip().lower()

    # If STM has no logic at all (no source column, no rule), can't verify
    if not stm_source and not business_rule:
        return "MISMATCH"

    # Special case: STM source is NULL (intentional NULL column)
    stm_source_lower = stm_source.lower()
    target_col_name = _normalize_stm_name(stm_col.get("target_column", ""))
    if re.match(r"^[,\s]*null\s+as\s+", stm_source_lower):
        noop_null_rules = ["general number rule 4", "general date rule 5", "general rule 5"]
        if business_rule in noop_null_rules:
            return "MATCH"
        # For non-noop rules with NULL source (e.g., flag rules):
        # Source is intentionally NULL — just check if the rule keywords match in DBT
        if business_rule:
            rule_pattern = GENERAL_RULE_PATTERNS.get(business_rule)
            if rule_pattern:
                keywords = rule_pattern["keywords"]
                if all(kw.lower() in dbt_lower for kw in keywords):
                    return "MATCH"
            # Target column in DBT is enough for source confirmation when source is NULL
            if target_col_name and target_col_name.lower() in dbt_lower:
                return "MATCH"
        return "MISMATCH"

    # --- CHECK 1: Source column match (strict) ---
    # Extract actual source column references from STM (table.column patterns)
    source_match = False
    target_col = _normalize_stm_name(stm_col.get("target_column", ""))
    stm_col_refs = re.findall(r"(\w+)\.(\w+)", stm_source)

    if stm_col_refs:
        # Must find at least one actual source column (not alias) in DBT
        for table_alias, col_name in stm_col_refs:
            if col_name.upper() == target_col:
                continue
            if col_name.lower() in dbt_lower:
                source_match = True
                break
        # Fallback: DBT cleansing layer references the target column name
        # (source mapping happens in an earlier CTE)
        if not source_match and target_col and target_col.lower() in dbt_lower:
            source_match = True
    elif stm_source:
        # Clean leading commas/spaces and check if it's constants/variables
        stm_cleaned = stm_source.lstrip(", ")
        if stm_cleaned.startswith("@") or stm_cleaned.startswith("'") or "@" in stm_source:
            # Resolve @variables from the transformation/FROM/WHERE field
            transformation = stm_col.get("transformation", "")
            var_values = _resolve_stm_variables(stm_source, transformation)
            if var_values:
                # Check if resolved values appear in DBT expression
                source_match = all(val.lower() in dbt_lower for val in var_values)
            else:
                # Can't resolve — accept if target column appears in DBT
                source_match = target_col and target_col.lower() in dbt_lower
        else:
            source_match = stm_source.lower() in dbt_lower
    else:
        source_match = True

    if not source_match:
        return "MISMATCH"

    # --- CHECK 2: Cleansing rule match (strict — ALL keywords must appear) ---
    # No-op rules ("ISNULL then NULL") — a simple column passthrough is valid
    noop_rules = ["general number rule 4", "general date rule 5", "general rule 5"]
    if business_rule in noop_rules:
        return "MATCH"

    if business_rule:
        rule_pattern = GENERAL_RULE_PATTERNS.get(business_rule)
        if rule_pattern:
            keywords = rule_pattern["keywords"]
            # ALL keywords must be present in DBT expression
            rule_match = all(kw.lower() in dbt_lower for kw in keywords)
        else:
            # Unknown rule — can't verify, fail
            rule_match = False
    else:
        rule_match = True

    if not rule_match:
        return "MISMATCH"

    return "MATCH"


def _compare_single_column(stm_col: dict, dbt_col: dict, jinja_metadata: dict, cleansing_map: dict, compiled_expressions: dict) -> dict:
    """Compare a matched STM-DBT column pair."""
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
    dbt_logic_full = compiled_expressions.get(col_name, "-") or "-"
    dbt_logic = _get_compiled_expression(col_name, compiled_expressions)
    logic_comparison = _compare_logic(stm_col, dbt_logic_full)

    has_mismatch = ("MISMATCH" in column_name_compare or datatype_comparison == "MISMATCH"
                    or scd_comparison == "MISMATCH" or logic_comparison == "MISMATCH")
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
        "dbt_logic": dbt_logic,
        "logic_comparison": logic_comparison,
        "suggestion": suggestion,
        "status": overall_status,
    }


def _name_mismatch_result(stm_col: dict, dbt_col: dict, jinja_metadata: dict, cleansing_map: dict, compiled_expressions: dict) -> dict:
    """Build result for columns with same expression but different names."""
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
    stm_logic = _build_stm_logic(stm_col)
    dbt_logic_full = compiled_expressions.get(col_name, "-") or "-"
    dbt_logic = _get_compiled_expression(col_name, compiled_expressions)
    logic_comparison = _compare_logic(stm_col, dbt_logic_full)

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
        "stm_logic": stm_logic,
        "dbt_logic": dbt_logic,
        "logic_comparison": logic_comparison,
        "suggestion": "Reverify",
        "status": "MISMATCH",
    }


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
        "stm_logic": _build_stm_logic(stm_col),
        "dbt_logic": "-",
        "logic_comparison": "MISMATCH",
        "suggestion": "Reverify",
        "status": "MISMATCH",
    }


def _extra_in_dbt(dbt_col: dict, compiled_expressions: dict) -> dict:
    col_name = dbt_col.get("column_name", "").upper()
    dbt_logic = _get_compiled_expression(col_name, compiled_expressions)
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
        "dbt_logic": dbt_logic,
        "logic_comparison": "MISMATCH",
        "suggestion": "Reverify",
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


def _compare_column_names(stm_name: str, dbt_name: str) -> str:
    """Compare STM and DBT column names."""
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

    for canonical, aliases in type_aliases.items():
        if stm_base in aliases and dbt_base in aliases:
            return "MATCH"

    return "MISMATCH"


def _infer_type_from_expression(expression: str) -> str:
    """Infer datatype from SQL expression syntax."""
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
