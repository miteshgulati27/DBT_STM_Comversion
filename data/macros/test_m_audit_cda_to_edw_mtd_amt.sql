{%- macro test_m_audit_cda_to_edw_mtd_amt(
    in_source_schema,
    in_source_table,
    in_target_schema,
    in_target_table,
    in_amount_col,
    in_date_col,
    in_audit_key,
    in_tolerance=0.01
) -%}

{#--
    Test macro for m_audit_cda_to_edw_mtd_amt.
    Validates that MTD amounts match between source and target within tolerance.
    Returns rows only when the test FAILS (amount mismatch beyond tolerance).

    Arguments:
        in_source_schema: Source schema name
        in_source_table: Source table name
        in_target_schema: Target schema name
        in_target_table: Target table name
        in_amount_col: Amount column to sum
        in_date_col: Date column for MTD filter
        in_audit_key: Unique audit identifier
        in_tolerance: Acceptable difference threshold (default 0.01)
--#}

WITH source_mtd AS (
    SELECT COALESCE(SUM({{ in_amount_col }}), 0) AS src_mtd_amt
    FROM {{ in_source_schema }}.{{ in_source_table }}
    WHERE DATE_TRUNC('MONTH', {{ in_date_col }}) = DATE_TRUNC('MONTH', CURRENT_DATE())
),

target_mtd AS (
    SELECT COALESCE(SUM({{ in_amount_col }}), 0) AS tgt_mtd_amt
    FROM {{ in_target_schema }}.{{ in_target_table }}
    WHERE DATE_TRUNC('MONTH', {{ in_date_col }}) = DATE_TRUNC('MONTH', CURRENT_DATE())
)

SELECT
    '{{ in_audit_key }}' AS audit_key,
    'MTD' AS audit_period,
    s.src_mtd_amt AS source_amount,
    t.tgt_mtd_amt AS target_amount,
    ABS(s.src_mtd_amt - t.tgt_mtd_amt) AS amount_difference
FROM source_mtd s
CROSS JOIN target_mtd t
WHERE ABS(s.src_mtd_amt - t.tgt_mtd_amt) > {{ in_tolerance }}

{%- endmacro -%}
