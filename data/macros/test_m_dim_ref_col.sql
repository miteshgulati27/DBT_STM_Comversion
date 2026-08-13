{%- macro test_m_dim_ref_col(
    in_fact_schema,
    in_fact_table,
    in_dim_schema,
    in_dim_table,
    in_fact_fk_col,
    in_dim_pk_col,
    in_allow_default=true,
    in_default_key_value=-1
) -%}

{#--
    Test macro: Validates dimension referential column integrity.
    Checks that all foreign key values in a fact table reference
    valid records in the dimension table.
    Returns rows only when validation FAILS (orphan FK values found).

    Arguments:
        in_fact_schema: Fact table schema
        in_fact_table: Fact table name
        in_dim_schema: Dimension table schema
        in_dim_table: Dimension table name
        in_fact_fk_col: Foreign key column in fact table
        in_dim_pk_col: Primary key column in dimension table
        in_allow_default: Whether to allow default key value (default: true)
        in_default_key_value: Default/unknown key value (default: -1)
--#}

SELECT
    f.{{ in_fact_fk_col }} AS orphan_key_value,
    COUNT(*) AS orphan_count,
    'REFERENTIAL_INTEGRITY_VIOLATION' AS test_failure
FROM {{ in_fact_schema }}.{{ in_fact_table }} f
LEFT JOIN {{ in_dim_schema }}.{{ in_dim_table }} d
    ON f.{{ in_fact_fk_col }} = d.{{ in_dim_pk_col }}
WHERE d.{{ in_dim_pk_col }} IS NULL
{% if in_allow_default %}
    AND f.{{ in_fact_fk_col }} != {{ in_default_key_value }}
{% endif %}
    AND f.{{ in_fact_fk_col }} IS NOT NULL
GROUP BY f.{{ in_fact_fk_col }}

{%- endmacro -%}
