{%- macro m_term_key_flatten_wide(
    in_source_relation,
    in_key_column,
    in_term_key_column,
    in_value_column,
    in_term_keys,
    in_effective_date_col='EFFECTIVE_DATE'
) -%}

{#--
    Flattens term key-value pairs into a wide (pivoted) format.
    Converts rows of key-value pairs into columns.

    Arguments:
        in_source_relation: Source relation with key-value term data
        in_key_column: Primary key column
        in_term_key_column: Column containing the term key/attribute name
        in_value_column: Column containing the term value
        in_term_keys: List of term keys to pivot into columns
        in_effective_date_col: Effective date column for ordering
--#}

SELECT
    {{ in_key_column }},
    {% for term_key in in_term_keys %}
    MAX(CASE WHEN {{ in_term_key_column }} = '{{ term_key }}' THEN {{ in_value_column }} END) AS {{ term_key }}
    {%- if not loop.last %},{% endif %}
    {% endfor %},
    MAX({{ in_effective_date_col }}) AS {{ in_effective_date_col }}
FROM {{ in_source_relation }}
GROUP BY {{ in_key_column }}

{%- endmacro -%}
