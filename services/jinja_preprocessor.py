import re


def preprocess_jinja(sql_content: str) -> tuple[str, dict]:
    """Strip Jinja syntax from DBT SQL, return clean SQL + metadata about macros used."""
    metadata = {"macros_used": {}, "sources": [], "refs": []}

    cleaned = sql_content

    cleaned = re.sub(r"\{\{\s*config\s*\(.*?\)\s*\}\}", "", cleaned, flags=re.DOTALL)

    def replace_source(match):
        schema = match.group(1).strip("'\"")
        table = match.group(2).strip("'\"")
        metadata["sources"].append({"schema": schema, "table": table})
        return f"{schema}.{table}"

    cleaned = re.sub(
        r"\{\{\s*source\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
        replace_source, cleaned
    )

    def replace_ref(match):
        model = match.group(1).strip("'\"")
        metadata["refs"].append(model)
        return model

    cleaned = re.sub(
        r"\{\{\s*ref\s*\(\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
        replace_ref, cleaned
    )

    def replace_m_cleansing(match):
        cleansing_type = match.group(1).strip("'\" ")
        column_name = match.group(2).strip("'\" ")
        if "m_cleansing" not in metadata["macros_used"]:
            metadata["macros_used"]["m_cleansing"] = []
        metadata["macros_used"]["m_cleansing"].append(f"{cleansing_type}:{column_name}")
        return column_name

    cleaned = re.sub(
        r"\{\{\s*m_cleansing\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]?([^'\")\s]+)['\"]?\s*\)\s*\}\}",
        replace_m_cleansing, cleaned
    )

    def replace_m_cleanse(match):
        cleansing_type = match.group(1).strip("'\" ")
        column_name = match.group(2).strip("'\" ")
        if "m_cleansing" not in metadata["macros_used"]:
            metadata["macros_used"]["m_cleansing"] = []
        metadata["macros_used"]["m_cleansing"].append(f"{cleansing_type}:{column_name}")
        return column_name

    cleaned = re.sub(
        r"\{\{\s*m_cleanse\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]?([^'\")\s]+)['\"]?\s*\)\s*\}\}",
        replace_m_cleanse, cleaned
    )

    def replace_known_macro(match):
        macro_name = match.group(1)
        inner_content = match.group(2).strip()
        if macro_name not in metadata["macros_used"]:
            metadata["macros_used"][macro_name] = []
        metadata["macros_used"][macro_name].append(inner_content)

        args = _split_macro_args(inner_content)
        if macro_name in ("m_cleansing", "m_cleanse") and len(args) >= 2:
            return args[-1].strip("'\" ")
        if macro_name == "m_is_incremental":
            return "1=1"
        if macro_name in ("m_scd2_scd1_int_stage_dedup", "m_scd2_scd1_marts"):
            return "/* SCD dedup macro */"
        return args[-1].strip("'\" ") if args else inner_content

    cleaned = re.sub(
        r"\{\{\s*(\w+)\s*\((.*?)\)\s*\}\}",
        replace_known_macro, cleaned, flags=re.DOTALL
    )

    cleaned = _handle_if_blocks(cleaned)
    cleaned = re.sub(r"\{%-?\s*set\s+.*?-%?\}", "", cleaned, flags=re.DOTALL)
    cleaned = re.sub(r"\{[%#].*?[%#]\}", "", cleaned, flags=re.DOTALL)
    cleaned = re.sub(r"\{\{.*?\}\}", "", cleaned, flags=re.DOTALL)

    return cleaned, metadata


def _handle_if_blocks(sql: str) -> str:
    """Handle {% if target.type %} blocks by keeping the else (Snowflake) branch."""
    pattern = r"\{%\s*if\s+.*?%\}(.*?)\{%\s*else\s*%\}(.*?)\{%\s*endif\s*%\}"
    result = re.sub(pattern, r"\2", sql, flags=re.DOTALL)

    pattern_no_else = r"\{%\s*if\s+.*?%\}(.*?)\{%\s*endif\s*%\}"
    result = re.sub(pattern_no_else, r"\1", result, flags=re.DOTALL)

    return result


def _split_macro_args(args_str: str) -> list:
    """Split macro arguments respecting nested quotes and parens."""
    args = []
    depth = 0
    current = []
    in_quote = None

    for ch in args_str:
        if ch in ("'", '"') and in_quote is None:
            in_quote = ch
            current.append(ch)
        elif ch == in_quote:
            in_quote = None
            current.append(ch)
        elif ch == '(' and in_quote is None:
            depth += 1
            current.append(ch)
        elif ch == ')' and in_quote is None:
            depth -= 1
            current.append(ch)
        elif ch == ',' and depth == 0 and in_quote is None:
            args.append(''.join(current).strip())
            current = []
        else:
            current.append(ch)

    if current:
        args.append(''.join(current).strip())

    return args
