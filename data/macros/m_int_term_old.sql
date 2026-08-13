{%- macro m_int_term_old(
    in_source_name,
    in_source_table,
    in_term_key,
    in_term_cols,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG',
    in_filter_condition=none
) -%}

{#--
    Legacy/old version of the term-processing macro.
    Retained for backward compatibility with existing models.

    Arguments:
        in_source_name: Source name in sources.yml
        in_source_table: Source table identifier
        in_term_key: Primary/business key column
        in_term_cols: List of term attribute columns
        in_effective_date_col: Effective date column name
        in_expiry_date_col: Expiry date column name
        in_current_flag_col: Current record flag column
        in_filter_condition: Optional WHERE clause filter
--#}

WITH source_data AS (
    SELECT
        {{ in_term_key }},
        {% for col in in_term_cols %}
        {{ col }},
        {% endfor %}
        {{ in_effective_date_col }},
        {{ in_expiry_date_col }},
        {{ in_current_flag_col }}
    FROM {{ source(in_source_name, in_source_table) }}
    WHERE 1=1
    {% if in_filter_condition is not none %}
        AND {{ in_filter_condition }}
    {% endif %}
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ in_term_key }}
            ORDER BY {{ in_effective_date_col }} DESC
        ) AS term_rank
    FROM source_data
),

term_output AS (
    SELECT
        {{ in_term_key }},
        {% for col in in_term_cols %}
        {{ col }},
        {% endfor %}
        {{ in_effective_date_col }},
        COALESCE({{ in_expiry_date_col }}, '9999-12-31'::DATE) AS {{ in_expiry_date_col }},
        CASE
            WHEN term_rank = 1 THEN 'Y'
            ELSE 'N'
        END AS {{ in_current_flag_col }}
    FROM ranked
)

SELECT * FROM term_output

{%- endmacro -%}
