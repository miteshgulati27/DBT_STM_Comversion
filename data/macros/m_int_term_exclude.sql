{%- macro m_int_term_exclude(
    in_source_name,
    in_source_table,
    in_term_key,
    in_term_cols,
    in_exclude_cols,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG',
    in_filter_condition=none
) -%}

{#--
    Term-processing macro that excludes specified columns from comparison logic.
    Used when certain columns should not trigger a new term record.

    Arguments:
        in_source_name: Source name in sources.yml
        in_source_table: Source table identifier
        in_term_key: Primary/business key column
        in_term_cols: List of all term attribute columns
        in_exclude_cols: List of columns to exclude from change detection
        in_effective_date_col: Effective date column name
        in_expiry_date_col: Expiry date column name
        in_current_flag_col: Current record flag column
        in_filter_condition: Optional WHERE clause filter
--#}

{%- set compare_cols = [] -%}
{%- for col in in_term_cols -%}
    {%- if col not in in_exclude_cols -%}
        {%- do compare_cols.append(col) -%}
    {%- endif -%}
{%- endfor -%}

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

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ in_term_key }}, {{ in_effective_date_col }}
            ORDER BY {{ in_effective_date_col }} DESC
        ) AS rn
    FROM source_data
),

term_records AS (
    SELECT
        {{ in_term_key }},
        {% for col in in_term_cols %}
        {{ col }},
        {% endfor %}
        {{ in_effective_date_col }},
        COALESCE({{ in_expiry_date_col }}, '9999-12-31'::DATE) AS {{ in_expiry_date_col }},
        CASE
            WHEN COALESCE({{ in_expiry_date_col }}, '9999-12-31'::DATE) >= CURRENT_DATE()
            THEN 'Y'
            ELSE 'N'
        END AS {{ in_current_flag_col }}
    FROM deduped
    WHERE rn = 1
)

SELECT * FROM term_records

{%- endmacro -%}
