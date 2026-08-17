import re
from pathlib import Path
from services.jinja_preprocessor import preprocess_jinja

try:
    import sqlglot
    from sqlglot import exp
    HAS_SQLGLOT = True
except ImportError:
    HAS_SQLGLOT = False


def _get_m_int_term_columns(jinja_metadata: dict, sql_content: str) -> list:
    """Generate known output columns for m_int_term macro based on parameters."""
    macros = jinja_metadata.get("macros_used", {})
    if "m_int_term" not in macros and "m_int_term_exclude" not in macros:
        return []

    lob = ""
    clause_type = "COVG"
    cvrbl_key_text = ""
    cvrbl_key_src_col = ""
    clause_key_text = ""
    term_table_name = ""

    lob_match = re.search(r"\{%\s*set\s+lob\s*=\s*['\"](\w+)['\"]", sql_content)
    if lob_match:
        lob = lob_match.group(1).upper()
    clause_match = re.search(r"\{%\s*set\s+clause_type\s*=\s*['\"](\w+)['\"]", sql_content)
    if clause_match:
        clause_type = clause_match.group(1).upper()
    cvrbl_text_match = re.search(r"\{%\s*set\s+cvrbl_key_text\s*=\s*['\"]([^'\"]+)['\"]", sql_content)
    if cvrbl_text_match:
        cvrbl_key_text = cvrbl_text_match.group(1)
    src_col_match = re.search(r"\{%\s*set\s+cvrbl_key_src_col\s*=\s*['\"]([^'\"]+)['\"]", sql_content)
    if src_col_match:
        cvrbl_key_src_col = src_col_match.group(1)
    clause_text_match = re.search(r"\{%\s*set\s+clause_key_text\s*=\s*['\"]([^'\"]+)['\"]", sql_content)
    if clause_text_match:
        clause_key_text = clause_text_match.group(1)
    table_match = re.search(r"\{%\s*set\s+term_table_name\s*=\s*['\"]([^'\"]+)['\"]", sql_content)
    if table_match:
        term_table_name = table_match.group(1)

    lob_clause_key = f"{lob}_{clause_type}_KEY"
    lob_cvrbl_key = f"{lob}_CVRBL_KEY"
    src_system = "GWPC"

    columns = [
        {"column_name": lob_clause_key, "expression": f"'{src_system}' || '-' || cast(PeriodID as varchar) || '-' || '{clause_key_text}' || '-' || cast(FixedID as varchar)", "source_tables": [term_table_name], "datatype": "VARCHAR"},
        {"column_name": "POL_KEY", "expression": f"'{src_system}' || '-' || cast(polper.PeriodID as varchar)", "source_tables": ["pc_policyperiod"], "datatype": "VARCHAR"},
        {"column_name": "POL_LINE_KEY", "expression": f"'{src_system}' || '-' || cast(polper.PeriodID as varchar) || '-' || cast(src.{cvrbl_key_src_col} as varchar)", "source_tables": [term_table_name], "datatype": "VARCHAR"},
        {"column_name": lob_cvrbl_key, "expression": f"'{src_system}' || '-' || cast(PeriodID as varchar) || '-' || '{cvrbl_key_text}' || '-' || cast(src.{cvrbl_key_src_col} as varchar)", "source_tables": [term_table_name], "datatype": "VARCHAR"},
        {"column_name": "END_EFF_DT", "expression": "cast(coalesce(src.EffectiveDate, polper.PeriodStart) as date)", "source_tables": [term_table_name, "pc_policyperiod"], "datatype": "DATE"},
        {"column_name": "END_EXP_DT", "expression": "cast(coalesce(src.ExpirationDate, polper.PeriodEnd) as date)", "source_tables": [term_table_name, "pc_policyperiod"], "datatype": "DATE"},
        {"column_name": "ETL_END_EFF_DTS", "expression": "to_timestamp(coalesce(src.EffectiveDate, polper.PeriodStart))", "source_tables": [], "datatype": "TIMESTAMP_NTZ"},
        {"column_name": "ETL_END_EXP_DTS", "expression": "to_timestamp(coalesce(src.ExpirationDate, polper.PeriodEnd))", "source_tables": [], "datatype": "TIMESTAMP_NTZ"},
        {"column_name": "Z_POL_EFF_DT", "expression": "cast(polper.PeriodStart as date)", "source_tables": ["pc_policyperiod"], "datatype": "DATE"},
        {"column_name": "Z_POL_EXP_DT", "expression": "cast(polper.PeriodEnd as date)", "source_tables": ["pc_policyperiod"], "datatype": "DATE"},
        {"column_name": "Z_POL_CHNG_TYPE", "expression": "src.changetype", "source_tables": [term_table_name], "datatype": "NUMBER"},
        {"column_name": "SOURCE_SYSTEM", "expression": f"'{src_system}'", "source_tables": [], "datatype": "VARCHAR"},
        {"column_name": "CVRBL_TYPE_CD", "expression": f"cast('{cvrbl_key_text}' as varchar(255))", "source_tables": [], "datatype": "VARCHAR"},
        {"column_name": "PATTERNCODE", "expression": "src.PatternCode", "source_tables": [term_table_name], "datatype": "VARCHAR"},
        {"column_name": "CURR_CD", "expression": "Currency.TYPECODE from pctl_currency", "source_tables": ["pctl_currency"], "datatype": "VARCHAR"},
        {"column_name": "TERMS", "expression": "object_agg(TermKey, TermValueJSON) from pc_etlcovtermpattern join pc_etlcovtermoption", "source_tables": ["pc_etlcovtermpattern", "pc_etlcovtermoption"], "datatype": "VARIANT"},
        {"column_name": "NOTERMS", "expression": "object_agg(NoTermKey, NoTermValue) from pc_etlclausepattern", "source_tables": ["pc_etlclausepattern"], "datatype": "VARIANT"},
        {"column_name": "ETL_ROW_EFF_DTS", "expression": "job.CloseDate from pc_job", "source_tables": ["pc_job"], "datatype": "TIMESTAMP_NTZ"},
    ]
    return columns


def parse_sql_file(sql_path: Path) -> dict:
    """Parse a DBT SQL file and extract column definitions."""
    sql_content = sql_path.read_text(encoding="utf-8")
    cleaned_sql, jinja_metadata = preprocess_jinja(sql_content)

    columns = []
    if HAS_SQLGLOT:
        columns = _parse_with_sqlglot(cleaned_sql)

    regex_columns = _parse_with_regex(cleaned_sql)

    if not columns:
        columns = regex_columns
    elif regex_columns:
        columns = columns + regex_columns

    json_columns = _extract_json_object_columns(cleaned_sql)
    if json_columns:
        columns = columns + json_columns

    if not columns:
        macro_columns = _get_m_int_term_columns(jinja_metadata, sql_content)
        if macro_columns:
            columns = macro_columns

    columns = _dedupe_prefer_non_null(columns)

    scd_map = _extract_scd_types(sql_content)
    if scd_map:
        for col in columns:
            col_name = col["column_name"].upper()
            if col_name in scd_map:
                col["scd_type"] = scd_map[col_name]

    return {
        "columns": columns,
        "jinja_metadata": jinja_metadata,
        "raw_sql": sql_content,
        "cleaned_sql": cleaned_sql,
    }


def _dedupe_prefer_non_null(columns: list) -> list:
    """When a column appears multiple times, keep the best (most informative) definition."""
    seen = {}
    for col in columns:
        name = col["column_name"].upper()
        if name not in seen:
            seen[name] = col
        else:
            if _expression_priority(col) > _expression_priority(seen[name]):
                seen[name] = col

    return list(seen.values())


def _expression_priority(col: dict) -> int:
    """Score expression by informativeness: CASE > function > direct ref > NULL."""
    expr = col.get("expression", "").strip().upper()
    if not expr or expr.startswith("NULL"):
        return 0
    if "CASE" in expr:
        return 4
    if "COALESCE" in expr or "CAST(" in expr:
        return 3
    if "||" in expr or "CONCAT" in expr:
        return 3
    if "." in expr:
        return 2
    return 1


def _parse_with_sqlglot(sql: str) -> list:
    """Use sqlglot to parse SQL and extract SELECT columns."""
    try:
        statements = sqlglot.parse(sql, read="snowflake", error_level=sqlglot.ErrorLevel.IGNORE)
    except Exception:
        return []

    columns = []
    for stmt in statements:
        if stmt is None:
            continue
        select = _find_final_select(stmt)
        if not select:
            continue

        for projection in select.expressions:
            col_info = _extract_column_info(projection)
            if col_info:
                columns.append(col_info)

    return columns


def _find_final_select(stmt):
    """Find the SELECT with the most explicit columns (not SELECT *)."""
    selects = list(stmt.find_all(exp.Select))
    if not selects:
        return stmt if isinstance(stmt, exp.Select) else None

    best = None
    best_count = 0
    for s in selects:
        exprs = s.expressions
        if len(exprs) == 1:
            first = exprs[0]
            if isinstance(first, exp.Star):
                continue
        if len(exprs) > best_count:
            best_count = len(exprs)
            best = s

    return best or selects[0]


def _extract_column_info(projection) -> dict | None:
    """Extract column name, expression, and source info from a SELECT projection."""
    alias = projection.alias_or_name if hasattr(projection, "alias_or_name") else ""
    if not alias or alias == "":
        expr_str = projection.sql(dialect="snowflake") if hasattr(projection, "sql") else str(projection)
        alias = expr_str.split(".")[-1] if "." in expr_str else expr_str

    expression = projection.sql(dialect="snowflake") if hasattr(projection, "sql") else str(projection)

    source_tables = set()
    for col in projection.find_all(exp.Column):
        if col.table:
            source_tables.add(col.table)

    datatype = "-"
    for cast in projection.find_all(exp.Cast):
        dtype = cast.to
        if dtype:
            datatype = dtype.sql(dialect="snowflake")
            break

    return {
        "column_name": alias.upper(),
        "expression": expression,
        "source_tables": list(source_tables),
        "datatype": datatype,
    }


def _parse_with_regex(sql: str) -> list:
    """Fallback: extract columns from all major SELECTs, prefer non-NULL definitions."""
    all_columns = []

    cleaned_match = re.search(r"_cleaned\s+AS\s*\(\s*SELECT\s+", sql, re.IGNORECASE)
    if cleaned_match:
        start = cleaned_match.end()
        select_body = _extract_until_top_level_from(sql, start)
        if select_body and select_body.count(',') > 2:
            cols = _extract_columns_from_select_body(select_body)
            all_columns.extend(cols)
            return all_columns

    all_selects = re.findall(r"SELECT\s+(.*?)\s+FROM\s+", sql, re.IGNORECASE | re.DOTALL)
    non_star = [s for s in all_selects if s.strip() != '*' and s.count(',') > 2]
    for select_body in non_star:
        cols = _extract_columns_from_select_body(select_body)
        all_columns.extend(cols)

    return all_columns


def _extract_until_top_level_from(sql: str, start: int) -> str:
    """Extract text from start until a FROM keyword at depth 0 (not inside parens)."""
    depth = 0
    i = start
    while i < len(sql) - 4:
        ch = sql[i]
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        elif depth == 0 and sql[i:i+4].upper() == 'FROM' and (i == 0 or not sql[i-1].isalnum()):
            after = sql[i+4:i+5] if i+4 < len(sql) else ' '
            if not after.isalnum() and after != '_':
                return sql[start:i]
        i += 1
    return sql[start:]


def _extract_columns_from_select_body(select_body: str) -> list:
    """Parse a single SELECT body into column definitions."""
    if not select_body:
        return []

    columns = []
    parts = _split_select_columns(select_body)

    for part in parts:
        part = part.strip()
        if not part:
            continue

        alias_match = re.search(r"\s+as\s+(\w+)\s*$", part, re.IGNORECASE)
        if alias_match:
            alias = alias_match.group(1)
            expression = part[:alias_match.start()].strip()
        else:
            tokens = part.split(".")
            alias = tokens[-1].strip()
            expression = part

        datatype = "-"
        cast_match = re.search(r"cast\s*\(.*?\s+as\s+(\w+(?:\([^)]*\))?)\s*\)", part, re.IGNORECASE)
        if cast_match:
            datatype = cast_match.group(1).upper()

        columns.append({
            "column_name": alias.upper(),
            "expression": expression,
            "source_tables": [],
            "datatype": datatype,
        })

    return columns


def _extract_scd_types(sql_content: str) -> dict:
    """Extract SCD type (1, 2, or N/A for keys) from {% set key_cols/scd1_cols/scd2_cols %} in SQL."""
    scd_map = {}

    key_match = re.search(r"\{%-?\s*set\s+key_cols\s*=\s*\[(.*?)\]", sql_content, re.DOTALL)
    if key_match:
        cols = re.findall(r"['\"](\w+)['\"]", key_match.group(1))
        for col in cols:
            scd_map[col.upper()] = "N/A"

    scd2_match = re.search(r"\{%-?\s*set\s+scd2_cols\s*=\s*\[(.*?)\]", sql_content, re.DOTALL)
    if scd2_match:
        cols = re.findall(r"['\"](\w+)['\"]", scd2_match.group(1))
        for col in cols:
            scd_map[col.upper()] = "2"

    scd1_match = re.search(r"\{%-?\s*set\s+scd1_cols\s*=\s*\[(.*?)\]", sql_content, re.DOTALL)
    if not scd1_match:
        scd1_match = re.search(r"\{%-?\s*set\s+scdl_cols\s*=\s*\[(.*?)\]", sql_content, re.DOTALL)
    if scd1_match:
        cols = re.findall(r"['\"](\w+)['\"]", scd1_match.group(1))
        for col in cols:
            scd_map[col.upper()] = "1"

    if not scd_map and re.search(r"\{\{\s*m_int_term\s*\(", sql_content):
        scd_map = _get_m_int_term_scd_types(sql_content)

    return scd_map


def _get_m_int_term_scd_types(sql_content: str) -> dict:
    """Derive SCD types for m_int_term macro models based on the macro's built-in SCD logic."""
    lob_match = re.search(r"set\s+lob\s*=\s*['\"](\w+)['\"]", sql_content)
    clause_match = re.search(r"set\s+clause_type\s*=\s*['\"](\w+)['\"]", sql_content)
    lob = lob_match.group(1).upper() if lob_match else "CA"
    clause = clause_match.group(1).upper() if clause_match else "COVG"

    clause_key = f"{lob}_{clause}_KEY"
    cvrbl_key = f"{lob}_CVRBL_KEY"

    scd_map = {}
    scd_map[clause_key] = "N/A"
    scd_map["END_EFF_DT"] = "N/A"

    scd1_cols = ["POL_KEY", "POL_LINE_KEY", cvrbl_key]
    for col in scd1_cols:
        scd_map[col] = "1"

    scd2_cols = [
        "END_EXP_DT", "ETL_END_EFF_DTS", "ETL_END_EXP_DTS",
        "Z_POL_EFF_DT", "Z_POL_EXP_DT", "Z_POL_CHNG_TYPE",
        "SOURCE_SYSTEM", "CVRBL_TYPE_CD", "PATTERNCODE", "CURR_CD",
        "TERMS", "NOTERMS", "ETL_ROW_EFF_DTS",
    ]
    for col in scd2_cols:
        scd_map[col] = "2"

    return scd_map


def _split_select_columns(select_body: str) -> list:
    """Split SELECT columns handling nested parentheses."""
    parts = []
    depth = 0
    current = []

    for char in select_body:
        if char == '(':
            depth += 1
            current.append(char)
        elif char == ')':
            depth -= 1
            current.append(char)
        elif char == ',' and depth == 0:
            parts.append(''.join(current))
            current = []
        else:
            current.append(char)

    if current:
        parts.append(''.join(current))

    return parts


def _extract_json_object_columns(sql: str) -> list:
    """Extract columns from object_construct/struct_pack JSON builders.

    Patterns:
      object_construct(KEY, value, KEY, value, ...)
      struct_pack(KEY := value, KEY := value, ...)
      object_construct_keep_null(KEY, value, ...)
    """
    columns = []

    struct_pack_pattern = re.finditer(
        r"(?:struct_pack|object_construct_keep_null|object_construct)\s*\(",
        sql, re.IGNORECASE
    )

    for match in struct_pack_pattern:
        start = match.end()
        body = _extract_paren_body(sql, start)
        if not body:
            continue

        if ":=" in body:
            pairs = re.findall(r"(\w+)\s*:=\s*(.*?)(?=,\s*\w+\s*:=|\s*$)", body, re.DOTALL)
            for key, expr in pairs:
                expr = expr.strip().rstrip(",")
                datatype = _infer_json_col_type(expr)
                columns.append({
                    "column_name": key.upper(),
                    "expression": expr[:200] if len(expr) > 200 else expr,
                    "source_tables": [],
                    "datatype": datatype,
                })
        else:
            parts = _split_select_columns(body)
            i = 0
            while i < len(parts) - 1:
                key = parts[i].strip().strip("'\"")
                expr = parts[i + 1].strip()
                if re.match(r"^\w+$", key):
                    datatype = _infer_json_col_type(expr)
                    columns.append({
                        "column_name": key.upper(),
                        "expression": expr[:200] if len(expr) > 200 else expr,
                        "source_tables": [],
                        "datatype": datatype,
                    })
                i += 2

    return columns


def _extract_paren_body(sql: str, start: int) -> str:
    """Extract content inside parentheses starting at position after '('."""
    depth = 1
    i = start
    while i < len(sql) and depth > 0:
        if sql[i] == '(':
            depth += 1
        elif sql[i] == ')':
            depth -= 1
        i += 1
    return sql[start:i - 1] if depth == 0 else ""


def _infer_json_col_type(expr: str) -> str:
    """Infer type from a JSON value expression using only expression syntax."""
    expr_lower = expr.lower().strip()

    if re.search(r"cast\s*\(.*?\s+as\s+(\w+)", expr_lower):
        m = re.search(r"cast\s*\(.*?\s+as\s+(\w+)", expr_lower)
        return m.group(1).upper()

    if "case" in expr_lower and ("'y'" in expr_lower or "'n'" in expr_lower):
        return "VARCHAR"

    if re.search(r"coalesce\s*\(.*?,\s*0\s*\)", expr_lower):
        return "NUMBER"

    if re.search(r"coalesce\s*\(.*?cast\(.*?as\s+varchar", expr_lower):
        return "VARCHAR"

    if re.search(r"nullif\s*\(.*?cast\(.*?as\s+varchar", expr_lower):
        return "VARCHAR"

    if re.search(r"coalesce\s*\(.*?,\s*' '\s*\)", expr_lower):
        return "VARCHAR"

    if re.search(r"coalesce\s*\(.*?,\s*'NOKEY'\s*\)", expr_lower):
        return "VARCHAR"

    return "-"
