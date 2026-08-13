"""
DBT Jinja Compiler — expands macros from data/macros/ into full SQL.
Not a full dbt compile (no DB queries), but resolves:
- {% set var = 'value' %} variable assignments
- {{ m_cleansing('TYPE', 'COL') }} → expanded CASE/COALESCE logic
- {{ m_int_term(...) }} → full term CTE structure
- {{ m_scd2_scd1_int_stage_dedup(...) }} → dedup SELECT
- {{ source('schema', 'table') }} → schema.table
- {{ ref('model') }} → model
- {{ config(...) }} → removed
- {% if %}...{% else %}...{% endif %} → picks else branch
"""
import re
from pathlib import Path

MACROS_DIR = None


def compile_sql(sql_path: Path, macros_dir: Path) -> str:
    """Compile a DBT SQL file by expanding all macros."""
    global MACROS_DIR
    MACROS_DIR = macros_dir

    sql_content = sql_path.read_text(encoding="utf-8")

    variables = _extract_set_variables(sql_content)

    compiled = sql_content

    compiled = re.sub(r"\{\{\s*config\s*\(.*?\)\s*\}\}", "", compiled, flags=re.DOTALL)

    compiled = re.sub(
        r"\{\{\s*source\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
        lambda m: f"{m.group(1)}.{m.group(2)}", compiled
    )

    compiled = re.sub(
        r"\{\{\s*ref\s*\(\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
        lambda m: m.group(1), compiled
    )

    compiled = _expand_m_cleansing_calls(compiled)

    compiled = _expand_m_int_term(compiled, variables)

    compiled = _expand_m_scd2_scd1(compiled, variables)

    compiled = _handle_if_blocks(compiled)

    compiled = re.sub(r"\{%-?\s*set\s+.*?-?%\}", "", compiled, flags=re.DOTALL)
    compiled = re.sub(r"\{%.*?%\}", "", compiled, flags=re.DOTALL)
    compiled = re.sub(r"\{\{.*?\}\}", "", compiled, flags=re.DOTALL)

    compiled = "\n".join(line for line in compiled.split("\n") if line.strip())

    return compiled


def _extract_set_variables(sql: str) -> dict:
    """Extract {% set var = 'value' %} assignments."""
    variables = {}
    for match in re.finditer(r"\{%\s*set\s+(\w+)\s*=\s*['\"]([^'\"]*)['\"]", sql):
        variables[match.group(1)] = match.group(2)
    return variables


def _expand_m_cleansing_calls(sql: str) -> str:
    """Expand {{ m_cleansing('TYPE', 'COL') }} and {{ m_cleanse('TYPE', 'COL') }}."""

    def replace_cleansing(match):
        cleansing_type = match.group(1).strip("'\" ")
        col = match.group(2).strip("'\" ")
        return _get_cleansing_expression(cleansing_type, col)

    sql = re.sub(
        r"\{\{\s*m_cleansing\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]?([^'\")\s]+)['\"]?\s*\)\s*\}\}",
        replace_cleansing, sql
    )
    sql = re.sub(
        r"\{\{\s*m_cleanse\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]?([^'\")\s]+)['\"]?\s*\)\s*\}\}",
        replace_cleansing, sql
    )
    return sql


def _get_cleansing_expression(cleansing_type: str, col: str) -> str:
    """Return the expanded SQL for a cleansing rule."""
    t = cleansing_type.upper()
    if t == "VARCHAR_SINGLESPACE":
        return f"(CASE WHEN {col} IS NULL OR TRIM({col})='' THEN ' ' ELSE TRIM({col}) END)"
    elif t == "VARCHAR_QUESTION":
        return f"(CASE WHEN {col} IS NULL OR TRIM({col})='' THEN '?' ELSE TRIM({col}) END)"
    elif t == "VARCHAR_NOKEY":
        return f"(CASE WHEN {col} IS NULL OR TRIM({col})='' THEN 'NOKEY' ELSE TRIM({col}) END)"
    elif t == "VARCHAR_NA":
        return f"(CASE WHEN {col} IS NULL OR {col}='' THEN 'N/A' ELSE TRIM({col}) END)"
    elif t == "VARCHAR_NA_LOWERCASE":
        return f"(CASE WHEN {col} IS NULL OR TRIM({col})='' THEN 'n/a' ELSE TRIM({col}) END)"
    elif t == "NUMERIC_ZERO":
        return f"(CASE WHEN {col} IS NULL THEN 0 ELSE {col} END)"
    elif t == "VARCHAR_FLAG_UNKNOWN":
        return f"(CASE WHEN {col} IS NULL OR {col}='' THEN 'U' ELSE TRIM({col}) END)"
    elif t == "VARCHAR_FLAG_Y_N_U":
        return f"(CASE WHEN TRIM({col})='true' THEN 'Y' WHEN TRIM({col})='false' THEN 'N' ELSE 'U' END)"
    elif t == "DATE_LOW":
        return f"(CASE WHEN {col} IS NULL THEN TO_DATE('1900-01-01') ELSE {col} END)"
    elif t == "DATE_HIGH":
        return f"(CASE WHEN {col} IS NULL THEN TO_DATE('9000-12-31') ELSE {col} END)"
    elif t == "TIMESTAMP_NTZ_LOW":
        return f"(CASE WHEN {col} IS NULL THEN TO_TIMESTAMP('1900-01-01 00:00:00') ELSE {col} END)"
    elif t == "TIMESTAMP_NTZ_HIGH":
        return f"(CASE WHEN {col} IS NULL THEN TO_TIMESTAMP('9000-12-31 00:00:00') ELSE {col} END)"
    else:
        return col


def _expand_m_int_term(sql: str, variables: dict) -> str:
    """Expand {{ m_int_term(...) }} into the full term SQL structure."""
    pattern = r"\{\{\s*m_int_term\s*\(.*?\)\s*\}\}"
    match = re.search(pattern, sql, re.DOTALL)
    if not match:
        return sql

    lob = variables.get("lob", "CA").upper()
    clause_type = variables.get("clause_type", "COVG").upper()
    cvrbl_key_text = variables.get("cvrbl_key_text", "")
    cvrbl_key_src_col = variables.get("cvrbl_key_src_col", "")
    clause_key_text = variables.get("clause_key_text", "")
    term_table_name = variables.get("term_table_name", "")
    cvrbl_key = variables.get("cvrbl_key", "CVRBL_KEY")

    lob_clause_key = f"{lob}_{clause_type}_KEY"
    lob_cvrbl_key = f"{lob}_CVRBL_KEY"
    src_system = "GWPC"

    if cvrbl_key.upper() == "POL_LINE":
        pol_line_expr = f"UPPER('{src_system}') || '-' || CAST(PeriodID AS VARCHAR) || '-' || CAST(src.{cvrbl_key_src_col} AS VARCHAR)"
        cvrbl_expr = "'NOKEY'"
    else:
        pol_line_expr = "'NOKEY'"
        cvrbl_expr = f"UPPER('{src_system}') || '-' || CAST(PeriodID AS VARCHAR) || '-' || '{cvrbl_key_text}' || '-' || CAST(src.{cvrbl_key_src_col} AS VARCHAR)"

    expanded = f"""
-- ============================================================
-- COMPILED FROM: m_int_term macro
-- Parameters: term_table_name='{term_table_name}', lob='{lob}', clause_type='{clause_type}'
--   cvrbl_key='{cvrbl_key}', cvrbl_key_text='{cvrbl_key_text}'
--   cvrbl_key_src_col='{cvrbl_key_src_col}', clause_key_text='{clause_key_text}'
-- ============================================================

WITH src_tbl AS (
    SELECT * FROM sources_{lob.lower()}.{term_table_name.lower()}
),
pc_policyperiod AS (
    SELECT * FROM sources_common.pc_policyperiod
),
pc_job AS (
    SELECT * FROM sources_common.pc_job
),
pctl_policyperiodstatus AS (
    SELECT * FROM sources_common.pctl_policyperiodstatus
),
pctl_currency AS (
    SELECT * FROM sources_common.pctl_currency
),
pc_etlclausepattern AS (
    SELECT * FROM sources_common.pc_etlclausepattern
),
pc_etlcovtermpattern AS (
    SELECT * FROM sources_common.pc_etlcovtermpattern
),
pc_etlcovtermoption AS (
    SELECT * FROM sources_common.pc_etlcovtermoption
),
pc_etlcovtermpackage AS (
    SELECT * FROM sources_common.pc_etlcovtermpackage
),
pc_etlpackterm AS (
    SELECT * FROM sources_common.pc_etlpackterm
),
etl_control_parm_latest AS (
    SELECT start_extract_date, end_extract_date FROM etl_control_parm
    QUALIFY ROW_NUMBER() OVER (ORDER BY etl_add_dts DESC) = 1
),
maxclsdt AS (
    SELECT pp.PERIODID, j.CLOSEDATE, pp.JOBID, pp.periodstart, pp.periodend, pp.id, pp.modelnumber, status.typecode
    FROM pc_policyperiod pp
    JOIN pc_job j ON pp.jobid = j.id
    JOIN pctl_policyperiodstatus status ON status.ID = pp.status
    WHERE status.TYPECODE = 'Bound'
    AND j.CloseDate <= (SELECT end_extract_date FROM etl_control_parm_latest)
),
term_src AS (
    SELECT t.ID, t.BRANCHID, t.FIXEDID, t.PATTERNCODE,
        polper.periodid, polper.Closedate, polper.modelnumber,
        Currency.TYPECODE AS CURR_CD,
        CAST(COALESCE(t.EffectiveDate, polper.PeriodStart) AS DATE) AS END_EFF_DT,
        CAST(COALESCE(t.ExpirationDate, polper.PeriodEnd) AS DATE) AS END_EXP_DT,
        CAST(polper.PeriodStart AS DATE) AS Z_POL_EFF_DT,
        CAST(polper.PeriodEnd AS DATE) AS Z_POL_EXP_DT,
        t.changetype AS Z_POL_CHNG_TYPE,
        -- Dynamic term columns from {term_table_name} (resolved at compile time)
        t.{cvrbl_key_src_col}
    FROM src_tbl t
    JOIN maxclsdt polper ON polper.ID = t.branchid
    JOIN pctl_currency Currency ON Currency.ID = t.Currency
),
unpivot_src AS (
    SELECT * FROM term_src
    -- UNPIVOT (TermValue FOR TermColNmOut IN (<dynamic term columns>))
),
detail_terms AS (
    SELECT DISTINCT src.ID, src.BRANCHID, src.FIXEDID, src.PATTERNCODE,
        src.{cvrbl_key_src_col}, src.periodid, src.Closedate, src.modelnumber, src.CURR_CD,
        END_EFF_DT, END_EXP_DT, Z_POL_EFF_DT, Z_POL_EXP_DT, Z_POL_CHNG_TYPE,
        termpatt.code AS TermCode, TermColNmOut, TermValue,
        termpkg.NAME, termopt.OPTIONCODE::STRING,
        TermValue::STRING AS TERM_VAL_CD,
        termpatt.name AS TermName,
        TRIM(REGEXP_REPLACE(termpatt.name, '[^\\d\\w\\s]', '')) AS termname_cleaned,
        TRIM(REGEXP_REPLACE(pkgs.NAME, '[^\\d\\w\\s]', '')) AS pkg_cleaned,
        REPLACE(REPLACE(COALESCE((TermCode||' '||termname_cleaned||COALESCE(' '||pkg_cleaned,'')),' ',' '),' ','_'),'__','_') AS term_desc_key,
        LOWER(COALESCE(pkgs.VALUETYPE, termpatt.VALUETYPE, termpatt.MODELTYPE)) AS TERM_VAL_TYPE_CD,
        COALESCE(pkgs.VALUE, termopt.VALUE, CAST(TermValue AS NUMERIC(20,4)))::STRING AS TERM_VAL_AMT,
        OBJECT_CONSTRUCT_KEEP_NULL('TermName', TermName, 'TermCode', TermCode,
            'TermValue', TERM_VAL_CD, 'TermTypeCode', TERM_VAL_TYPE_CD,
            'CodeIdentifier', clausepatt.CODEIDENTIFIER, 'PatternCode', src.PatternCode,
            'ModelType', termpatt.MODELTYPE) AS TermValueJSON
    FROM unpivot_src src
    JOIN pc_etlclausepattern clausepatt ON clausepatt.PatternID = src.PatternCode
    LEFT JOIN pc_etlcovtermpattern termpatt ON termpatt.ClausePatternID = clausepatt.ID AND UPPER(TermColNmOut) = UPPER(termpatt.ColumnName)
    LEFT JOIN pc_etlcovtermoption termopt ON termopt.CoverageTermPatternID = termpatt.ID AND TermValue = termopt.PatternID
    LEFT JOIN pc_etlcovtermpackage termpkg ON termpkg.CoverageTermPatternID = termpatt.ID
    LEFT JOIN pc_etlpackterm pkgs ON pkgs.CovTermPackID = termpkg.ID
),
ctagg AS (
    SELECT ID, BRANCHID, FIXEDID, PATTERNCODE, periodid, Closedate, modelnumber, CURR_CD,
        END_EFF_DT, END_EXP_DT, Z_POL_EFF_DT, Z_POL_EXP_DT, Z_POL_CHNG_TYPE,
        {cvrbl_key_src_col},
        OBJECT_AGG(TermKey, TermValueJSON) AS Terms,
        OBJECT_AGG(NoTermKey, NoTermValue) AS NoTerms
    FROM detail_terms
    GROUP BY ID, BRANCHID, FIXEDID, PATTERNCODE, periodid, Closedate, modelnumber, CURR_CD,
        END_EFF_DT, END_EXP_DT, Z_POL_EFF_DT, Z_POL_EXP_DT, Z_POL_CHNG_TYPE, {cvrbl_key_src_col}
),
INT_TERMS AS (
    SELECT
        UPPER('{src_system}') || '-' || CAST(PeriodID AS VARCHAR) || '-' || '{clause_key_text}' || '-' || CAST(FixedID AS VARCHAR) AS {lob_clause_key},
        UPPER('{src_system}') || '-' || CAST(PeriodID AS VARCHAR) AS POL_KEY,
        {pol_line_expr} AS POL_LINE_KEY,
        {cvrbl_expr} AS {lob_cvrbl_key},
        END_EFF_DT, END_EXP_DT,
        TO_TIMESTAMP(END_EFF_DT) AS ETL_END_EFF_DTS,
        TO_TIMESTAMP(END_EXP_DT) AS ETL_END_EXP_DTS,
        Z_POL_EFF_DT, Z_POL_EXP_DT, Z_POL_CHNG_TYPE,
        '{src_system}' AS SOURCE_SYSTEM,
        CAST('{cvrbl_key_text}' AS VARCHAR(255)) AS CVRBL_TYPE_CD,
        PatternCode,
        CURR_CD,
        Terms, NoTerms,
        CloseDate AS ETL_ROW_EFF_DTS
    FROM ctagg src
),
INT_TERM_CLEANSE AS (
    SELECT
        {_get_cleansing_expression('VARCHAR_NOKEY', lob_clause_key)} AS {lob_clause_key},
        {_get_cleansing_expression('VARCHAR_NOKEY', 'POL_KEY')} AS POL_KEY,
        {_get_cleansing_expression('VARCHAR_NOKEY', 'POL_LINE_KEY')} AS POL_LINE_KEY,
        {_get_cleansing_expression('VARCHAR_NOKEY', lob_cvrbl_key)} AS {lob_cvrbl_key},
        {_get_cleansing_expression('DATE_LOW', 'END_EFF_DT')} AS END_EFF_DT,
        {_get_cleansing_expression('DATE_HIGH', 'END_EXP_DT')} AS END_EXP_DT,
        {_get_cleansing_expression('TIMESTAMP_NTZ_LOW', 'ETL_END_EFF_DTS')} AS ETL_END_EFF_DTS,
        {_get_cleansing_expression('TIMESTAMP_NTZ_HIGH', 'ETL_END_EXP_DTS')} AS ETL_END_EXP_DTS,
        {_get_cleansing_expression('DATE_LOW', 'Z_POL_EFF_DT')} AS Z_POL_EFF_DT,
        {_get_cleansing_expression('DATE_HIGH', 'Z_POL_EXP_DT')} AS Z_POL_EXP_DT,
        {_get_cleansing_expression('NUMERIC_ZERO', 'Z_POL_CHNG_TYPE')} AS Z_POL_CHNG_TYPE,
        {_get_cleansing_expression('VARCHAR_QUESTION', 'SOURCE_SYSTEM')} AS SOURCE_SYSTEM,
        {_get_cleansing_expression('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD')} AS CVRBL_TYPE_CD,
        PatternCode,
        {_get_cleansing_expression('VARCHAR_SINGLESPACE', 'CURR_CD')} AS CURR_CD,
        Terms, NoTerms,
        {_get_cleansing_expression('TIMESTAMP_NTZ_LOW', 'ETL_ROW_EFF_DTS')} AS ETL_ROW_EFF_DTS
    FROM INT_TERMS src
)
-- SCD2/SCD1 dedup stage
SELECT scd1.{lob_clause_key}, scd1.END_EFF_DT,
    END_EXP_DT, ETL_END_EFF_DTS, ETL_END_EXP_DTS, Z_POL_EFF_DT, Z_POL_EXP_DT,
    Z_POL_CHNG_TYPE, SOURCE_SYSTEM, CVRBL_TYPE_CD, PatternCode, CURR_CD, Terms, NoTerms,
    ETL_ROW_EFF_DTS,
    POL_KEY, POL_LINE_KEY, {lob_cvrbl_key}
FROM INT_TERM_CLEANSE scd2
LEFT JOIN (
    SELECT POL_KEY, POL_LINE_KEY, {lob_cvrbl_key}, {lob_clause_key}, END_EFF_DT
    FROM INT_TERM_CLEANSE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY {lob_clause_key}, END_EFF_DT ORDER BY ETL_ROW_EFF_DTS DESC) = 1
) scd1
ON scd1.{lob_clause_key} = scd2.{lob_clause_key} AND scd1.END_EFF_DT = scd2.END_EFF_DT
"""
    return sql[:match.start()] + expanded + sql[match.end():]


def _expand_m_scd2_scd1(sql: str, variables: dict) -> str:
    """Expand {{ m_scd2_scd1_int_stage_dedup(...) }}."""
    pattern = r"\{\{\s*m_scd2_scd1_int_stage_dedup\s*\(.*?\)\s*\}\}"
    match = re.search(pattern, sql, re.DOTALL)
    if not match:
        return sql
    return sql[:match.start()] + "-- [SCD2/SCD1 dedup applied in final SELECT above]" + sql[match.end():]


def _handle_if_blocks(sql: str) -> str:
    """Handle {% if %}...{% else %}...{% endif %} — keep else branch."""
    pattern = r"\{%\s*if\s+.*?%\}(.*?)\{%\s*else\s*%\}(.*?)\{%\s*endif\s*%\}"
    result = re.sub(pattern, r"\2", sql, flags=re.DOTALL)
    pattern_no_else = r"\{%\s*if\s+.*?%\}(.*?)\{%\s*endif\s*%\}"
    result = re.sub(pattern_no_else, r"\1", result, flags=re.DOTALL)
    return result
