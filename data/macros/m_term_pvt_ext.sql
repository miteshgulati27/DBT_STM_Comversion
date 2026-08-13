{%- macro m_term_pvt_ext(
    in_source_relation,
    in_key_column,
    in_term_key_column,
    in_value_column,
    in_term_keys,
    in_ext_source_relation=none,
    in_ext_key_column=none,
    in_ext_cols=none,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG'
) -%}

{#--
    Term Pivot Extended macro.
    Pivots term key-value data into wide format and optionally joins
    with an external source for enrichment.

    Arguments:
        in_source_relation: Source relation with term key-value data
        in_key_column: Primary key column
        in_term_key_column: Column containing term attribute names
        in_value_column: Column containing term values
        in_term_keys: List of term keys to pivot
        in_ext_source_relation: Optional external source for enrichment
        in_ext_key_column: Join key for external source
        in_ext_cols: Columns to include from external source
        in_effective_date_col: Effective date column
        in_expiry_date_col: Expiry date column
        in_current_flag_col: Current flag column
--#}

WITH pivoted AS (
    SELECT
        {{ in_key_column }},
        {% for term_key in in_term_keys %}
        MAX(CASE WHEN {{ in_term_key_column }} = '{{ term_key }}' THEN {{ in_value_column }} END) AS {{ term_key }}
        {%- if not loop.last %},{% endif %}
        {% endfor %},
        MAX({{ in_effective_date_col }}) AS {{ in_effective_date_col }},
        MAX({{ in_expiry_date_col }}) AS {{ in_expiry_date_col }},
        MAX({{ in_current_flag_col }}) AS {{ in_current_flag_col }}
    FROM {{ in_source_relation }}
    GROUP BY {{ in_key_column }}
)

{% if in_ext_source_relation is not none and in_ext_cols is not none %}
, enriched AS (
    SELECT
        p.*,
        {% for col in in_ext_cols %}
        e.{{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM pivoted p
    LEFT JOIN {{ in_ext_source_relation }} e
        ON p.{{ in_key_column }} = e.{{ in_ext_key_column }}
)

SELECT * FROM enriched

{% else %}

SELECT * FROM pivoted

{% endif %}

{%- endmacro -%}
