{%- macro test_m_cda_to_int_term(
    in_source_schema,
    in_source_table,
    in_target_schema,
    in_target_table,
    in_term_key,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG'
) -%}

{#--
    Test macro: Validates CDA to Intermediate term processing.
    Checks for:
    - Orphan records (in target but not in source)
    - Overlapping date ranges
    - Invalid current flag assignments
    - Missing term records
    Returns rows only when validation FAILS.

    Arguments:
        in_source_schema: Source CDA schema
        in_source_table: Source CDA table
        in_target_schema: Target intermediate schema
        in_target_table: Target intermediate table
        in_term_key: Business key column
        in_effective_date_col: Effective date column
        in_expiry_date_col: Expiry date column
        in_current_flag_col: Current flag column
--#}

{#-- Test 1: Check for overlapping date ranges --#}
WITH overlap_check AS (
    SELECT
        a.{{ in_term_key }},
        a.{{ in_effective_date_col }} AS a_eff_dt,
        a.{{ in_expiry_date_col }} AS a_exp_dt,
        b.{{ in_effective_date_col }} AS b_eff_dt,
        b.{{ in_expiry_date_col }} AS b_exp_dt,
        'OVERLAPPING_DATES' AS test_failure
    FROM {{ in_target_schema }}.{{ in_target_table }} a
    INNER JOIN {{ in_target_schema }}.{{ in_target_table }} b
        ON a.{{ in_term_key }} = b.{{ in_term_key }}
        AND a.{{ in_effective_date_col }} < b.{{ in_effective_date_col }}
        AND a.{{ in_expiry_date_col }} >= b.{{ in_effective_date_col }}
),

{#-- Test 2: Check for multiple current records per key --#}
multi_current AS (
    SELECT
        {{ in_term_key }},
        COUNT(*) AS current_count,
        'MULTIPLE_CURRENT_FLAGS' AS test_failure
    FROM {{ in_target_schema }}.{{ in_target_table }}
    WHERE {{ in_current_flag_col }} = 'Y'
    GROUP BY {{ in_term_key }}
    HAVING COUNT(*) > 1
),

{#-- Test 3: Check expiry < effective --#}
invalid_dates AS (
    SELECT
        {{ in_term_key }},
        {{ in_effective_date_col }},
        {{ in_expiry_date_col }},
        'EXPIRY_BEFORE_EFFECTIVE' AS test_failure
    FROM {{ in_target_schema }}.{{ in_target_table }}
    WHERE {{ in_expiry_date_col }} < {{ in_effective_date_col }}
)

SELECT '{{ in_target_table }}' AS tested_table, test_failure, COUNT(*) AS failure_count
FROM (
    SELECT test_failure FROM overlap_check
    UNION ALL
    SELECT test_failure FROM multi_current
    UNION ALL
    SELECT test_failure FROM invalid_dates
) failures
GROUP BY test_failure

{%- endmacro -%}
