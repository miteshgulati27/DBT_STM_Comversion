{%- macro m_audit_cda_to_edw_cnt_cvrbl(
    in_source_schema,
    in_source_table,
    in_target_schema,
    in_target_table,
    in_coverage_col,
    in_coverage_value,
    in_audit_key
) -%}

{#--
    Audit macro: Compares row counts between CDA source and EDW target
    with a coverable/variable filter applied.

    Arguments:
        in_source_schema: Source schema name
        in_source_table: Source table name
        in_target_schema: Target schema name
        in_target_table: Target table name
        in_coverage_col: Column to apply coverage filter
        in_coverage_value: Value for coverage filter
        in_audit_key: Unique audit identifier
--#}

WITH source_count AS (
    SELECT COUNT(*) AS src_cnt
    FROM {{ in_source_schema }}.{{ in_source_table }}
    WHERE {{ in_coverage_col }} = '{{ in_coverage_value }}'
),

target_count AS (
    SELECT COUNT(*) AS tgt_cnt
    FROM {{ in_target_schema }}.{{ in_target_table }}
    WHERE {{ in_coverage_col }} = '{{ in_coverage_value }}'
),

audit_result AS (
    SELECT
        '{{ in_audit_key }}' AS audit_key,
        '{{ in_source_schema }}.{{ in_source_table }}' AS source_table,
        '{{ in_target_schema }}.{{ in_target_table }}' AS target_table,
        '{{ in_coverage_col }}' AS coverage_column,
        '{{ in_coverage_value }}' AS coverage_value,
        s.src_cnt AS source_count,
        t.tgt_cnt AS target_count,
        s.src_cnt - t.tgt_cnt AS count_difference,
        CASE
            WHEN s.src_cnt = t.tgt_cnt THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status,
        CURRENT_TIMESTAMP() AS audit_timestamp
    FROM source_count s
    CROSS JOIN target_count t
)

SELECT * FROM audit_result

{%- endmacro -%}
