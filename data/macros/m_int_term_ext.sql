{%- macro m_int_term_ext(
    in_source_name,
    in_source_table,
    in_term_key,
    in_term_cols,
    in_ext_source_name,
    in_ext_source_table,
    in_ext_key,
    in_ext_cols,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG',
    in_filter_condition=none
) -%}

{#--
    Extended term-processing macro that joins with an external source.
    Enriches term records with additional attributes from an external table.

    Arguments:
        in_source_name: Primary source name
        in_source_table: Primary source table
        in_term_key: Primary/business key column
        in_term_cols: List of term attribute columns from primary source
        in_ext_source_name: External source name
        in_ext_source_table: External source table
        in_ext_key: Join key for external source
        in_ext_cols: List of columns from external source
        in_effective_date_col: Effective date column
        in_expiry_date_col: Expiry date column
        in_current_flag_col: Current record flag column
        in_filter_condition: Optional WHERE clause filter
--#}

WITH primary_source AS (
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

ext_source AS (
    SELECT
        {{ in_ext_key }},
        {% for col in in_ext_cols %}
        {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM {{ source(in_ext_source_name, in_ext_source_table) }}
),

joined AS (
    SELECT
        p.{{ in_term_key }},
        {% for col in in_term_cols %}
        p.{{ col }},
        {% endfor %}
        {% for col in in_ext_cols %}
        e.{{ col }},
        {% endfor %}
        p.{{ in_effective_date_col }},
        COALESCE(p.{{ in_expiry_date_col }}, '9999-12-31'::DATE) AS {{ in_expiry_date_col }},
        CASE
            WHEN COALESCE(p.{{ in_expiry_date_col }}, '9999-12-31'::DATE) >= CURRENT_DATE()
            THEN 'Y'
            ELSE 'N'
        END AS {{ in_current_flag_col }}
    FROM primary_source p
    LEFT JOIN ext_source e
        ON p.{{ in_term_key }} = e.{{ in_ext_key }}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ in_term_key }}, {{ in_effective_date_col }}
            ORDER BY {{ in_effective_date_col }} DESC
        ) AS rn
    FROM joined
)

SELECT * FROM deduped WHERE rn = 1

{%- endmacro -%}
