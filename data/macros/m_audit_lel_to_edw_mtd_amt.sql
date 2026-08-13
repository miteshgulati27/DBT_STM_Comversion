{%- macro m_audit_lel_to_edw_mtd_amt(
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
    Audit macro: Compares Month-To-Date amounts between LEL source and EDW target.
    Variant of the CDA audit for LEL (Lateral Element) sources.

    Arguments:
        in_source_schema: LEL source schema name
        in_source_table: LEL source table name
        in_target_schema: EDW target schema name
        in_target_table: EDW target table name
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
),

audit_result AS (
    SELECT
        '{{ in_audit_key }}' AS audit_key,
        'LEL_TO_EDW' AS audit_source,
        '{{ in_source_schema }}.{{ in_source_table }}' AS source_table,
        '{{ in_target_schema }}.{{ in_target_table }}' AS target_table,
        'MTD' AS audit_period,
        '{{ in_amount_col }}' AS amount_column,
        s.src_mtd_amt AS source_amount,
        t.tgt_mtd_amt AS target_amount,
        ABS(s.src_mtd_amt - t.tgt_mtd_amt) AS amount_difference,
        CASE
            WHEN ABS(s.src_mtd_amt - t.tgt_mtd_amt) <= {{ in_tolerance }} THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status,
        CURRENT_TIMESTAMP() AS audit_timestamp
    FROM source_mtd s
    CROSS JOIN target_mtd t
)

SELECT * FROM audit_result

{%- endmacro -%}
