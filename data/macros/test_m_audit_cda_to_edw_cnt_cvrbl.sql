{%- macro test_m_audit_cda_to_edw_cnt_cvrbl(
    in_source_schema,
    in_source_table,
    in_target_schema,
    in_target_table,
    in_coverage_col,
    in_coverage_value,
    in_audit_key,
    in_threshold=0
) -%}

{#--
    Test macro for m_audit_cda_to_edw_cnt_cvrbl.
    Validates that source and target row counts match within threshold
    for a specific coverage variable.
    Returns rows only when the test FAILS (count mismatch beyond threshold).

    Arguments:
        in_source_schema: Source schema name
        in_source_table: Source table name
        in_target_schema: Target schema name
        in_target_table: Target table name
        in_coverage_col: Column to apply coverage filter
        in_coverage_value: Value for coverage filter
        in_audit_key: Unique audit identifier
        in_threshold: Acceptable count difference (default: 0)
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
)

SELECT
    '{{ in_audit_key }}' AS audit_key,
    '{{ in_coverage_value }}' AS coverage_value,
    s.src_cnt AS source_count,
    t.tgt_cnt AS target_count,
    ABS(s.src_cnt - t.tgt_cnt) AS count_difference
FROM source_count s
CROSS JOIN target_count t
WHERE ABS(s.src_cnt - t.tgt_cnt) > {{ in_threshold }}

{%- endmacro -%}
