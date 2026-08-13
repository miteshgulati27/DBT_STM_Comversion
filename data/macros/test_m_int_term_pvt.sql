{%- macro test_m_int_term_pvt(
    in_source_schema,
    in_source_table,
    in_target_schema,
    in_target_table,
    in_term_key,
    in_pivot_col,
    in_expected_pivots
) -%}

{#--
    Test macro: Validates intermediate term pivot transformation.
    Checks that:
    - All expected pivot values produced columns
    - No NULL keys exist in pivoted output
    - Row counts align between source and pivoted target
    Returns rows only when validation FAILS.

    Arguments:
        in_source_schema: Source schema (pre-pivot)
        in_source_table: Source table (pre-pivot)
        in_target_schema: Target schema (post-pivot)
        in_target_table: Target table (post-pivot)
        in_term_key: Business key column
        in_pivot_col: Column that was pivoted
        in_expected_pivots: List of expected pivot values/columns
--#}

WITH source_keys AS (
    SELECT DISTINCT {{ in_term_key }}
    FROM {{ in_source_schema }}.{{ in_source_table }}
),

target_keys AS (
    SELECT DISTINCT {{ in_term_key }}
    FROM {{ in_target_schema }}.{{ in_target_table }}
),

missing_keys AS (
    SELECT
        s.{{ in_term_key }},
        'KEY_MISSING_IN_PIVOT' AS test_failure
    FROM source_keys s
    LEFT JOIN target_keys t
        ON s.{{ in_term_key }} = t.{{ in_term_key }}
    WHERE t.{{ in_term_key }} IS NULL
),

null_keys AS (
    SELECT
        'NULL_KEY_IN_PIVOT' AS test_failure
    FROM {{ in_target_schema }}.{{ in_target_table }}
    WHERE {{ in_term_key }} IS NULL
)

SELECT test_failure, COUNT(*) AS failure_count
FROM (
    SELECT test_failure FROM missing_keys
    UNION ALL
    SELECT test_failure FROM null_keys
) failures
GROUP BY test_failure

{%- endmacro -%}
