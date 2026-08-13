{%- macro test_m_int_to_cs(
    in_int_schema,
    in_int_table,
    in_cs_schema,
    in_cs_table,
    in_business_key,
    in_effective_date_col='EFFECTIVE_DATE',
    in_current_flag_col='CURRENT_FLAG'
) -%}

{#--
    Test macro: Validates Intermediate to Conformed Stage transformation.
    Checks for:
    - Missing records in conformed stage
    - Duplicate business keys in current records
    - Count reconciliation between layers
    Returns rows only when validation FAILS.

    Arguments:
        in_int_schema: Intermediate schema
        in_int_table: Intermediate table
        in_cs_schema: Conformed stage schema
        in_cs_table: Conformed stage table
        in_business_key: Business key column
        in_effective_date_col: Effective date column
        in_current_flag_col: Current flag column
--#}

WITH int_current AS (
    SELECT {{ in_business_key }}, {{ in_effective_date_col }}
    FROM {{ in_int_schema }}.{{ in_int_table }}
    WHERE {{ in_current_flag_col }} = 'Y'
),

cs_records AS (
    SELECT {{ in_business_key }}, {{ in_effective_date_col }}
    FROM {{ in_cs_schema }}.{{ in_cs_table }}
),

missing_in_cs AS (
    SELECT
        i.{{ in_business_key }},
        'MISSING_IN_CONFORMED_STAGE' AS test_failure
    FROM int_current i
    LEFT JOIN cs_records c
        ON i.{{ in_business_key }} = c.{{ in_business_key }}
    WHERE c.{{ in_business_key }} IS NULL
),

duplicate_cs_keys AS (
    SELECT
        {{ in_business_key }},
        'DUPLICATE_KEY_IN_CS' AS test_failure
    FROM {{ in_cs_schema }}.{{ in_cs_table }}
    GROUP BY {{ in_business_key }}
    HAVING COUNT(*) > 1
)

SELECT test_failure, COUNT(*) AS failure_count
FROM (
    SELECT test_failure FROM missing_in_cs
    UNION ALL
    SELECT test_failure FROM duplicate_cs_keys
) failures
GROUP BY test_failure

{%- endmacro -%}
