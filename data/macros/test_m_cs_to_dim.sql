{%- macro test_m_cs_to_dim(
    in_cs_schema,
    in_cs_table,
    in_dim_schema,
    in_dim_table,
    in_business_key,
    in_surrogate_key=none
) -%}

{#--
    Test macro: Validates Conformed Stage to Dimension transformation.
    Checks for:
    - Missing business keys in dimension
    - Duplicate surrogate keys
    - Null business keys
    - Referential integrity
    Returns rows only when validation FAILS.

    Arguments:
        in_cs_schema: Conformed stage schema
        in_cs_table: Conformed stage table
        in_dim_schema: Dimension schema
        in_dim_table: Dimension table
        in_business_key: Business key column
        in_surrogate_key: Surrogate key column (optional)
--#}

WITH missing_in_dim AS (
    SELECT
        cs.{{ in_business_key }},
        'MISSING_IN_DIMENSION' AS test_failure
    FROM {{ in_cs_schema }}.{{ in_cs_table }} cs
    LEFT JOIN {{ in_dim_schema }}.{{ in_dim_table }} dim
        ON cs.{{ in_business_key }} = dim.{{ in_business_key }}
    WHERE dim.{{ in_business_key }} IS NULL
),

null_business_keys AS (
    SELECT
        {{ in_business_key }},
        'NULL_BUSINESS_KEY' AS test_failure
    FROM {{ in_dim_schema }}.{{ in_dim_table }}
    WHERE {{ in_business_key }} IS NULL
)

{% if in_surrogate_key is not none %}
, duplicate_surrogates AS (
    SELECT
        {{ in_surrogate_key }},
        COUNT(*) AS dup_count,
        'DUPLICATE_SURROGATE_KEY' AS test_failure
    FROM {{ in_dim_schema }}.{{ in_dim_table }}
    GROUP BY {{ in_surrogate_key }}
    HAVING COUNT(*) > 1
)
{% endif %}

SELECT test_failure, COUNT(*) AS failure_count
FROM (
    SELECT test_failure FROM missing_in_dim
    UNION ALL
    SELECT test_failure FROM null_business_keys
    {% if in_surrogate_key is not none %}
    UNION ALL
    SELECT test_failure FROM duplicate_surrogates
    {% endif %}
) failures
GROUP BY test_failure

{%- endmacro -%}
