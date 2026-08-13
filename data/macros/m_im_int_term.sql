{%- macro m_im_int_term(
    in_source_name,
    in_source_table,
    in_term_key,
    in_term_cols,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG',
    in_incremental_col=none,
    in_incremental_lookback=3
) -%}

{#--
    Incremental Model Intermediate Term macro.
    Variant of m_int_term optimized for incremental materialization.
    Processes only new/changed term records since last run.

    Arguments:
        in_source_name: Source name in sources.yml
        in_source_table: Source table identifier
        in_term_key: Primary/business key column
        in_term_cols: List of term attribute columns
        in_effective_date_col: Effective date column name
        in_expiry_date_col: Expiry date column name
        in_current_flag_col: Current record flag column
        in_incremental_col: Column used for incremental filter
        in_incremental_lookback: Days to look back for incremental (default: 3)
--#}

{% if m_is_incremental() %}

WITH incremental_source AS (
    SELECT
        {{ in_term_key }},
        {% for col in in_term_cols %}
        {{ col }},
        {% endfor %}
        {{ in_effective_date_col }},
        {{ in_expiry_date_col }},
        {{ in_current_flag_col }}
    FROM {{ source(in_source_name, in_source_table) }}
    {% if in_incremental_col is not none %}
    WHERE {{ in_incremental_col }} >= DATEADD(DAY, -{{ in_incremental_lookback }}, CURRENT_DATE())
    {% endif %}
),

existing_current AS (
    SELECT {{ in_term_key }}, {{ in_effective_date_col }}
    FROM {{ this }}
    WHERE {{ in_current_flag_col }} = 'Y'
),

new_or_changed AS (
    SELECT s.*
    FROM incremental_source s
    LEFT JOIN existing_current e
        ON s.{{ in_term_key }} = e.{{ in_term_key }}
        AND s.{{ in_effective_date_col }} = e.{{ in_effective_date_col }}
    WHERE e.{{ in_term_key }} IS NULL
)

SELECT * FROM new_or_changed

{% else %}

{{ m_int_term(
    in_source_name,
    in_source_table,
    in_term_key,
    in_term_cols,
    in_effective_date_col,
    in_expiry_date_col,
    in_current_flag_col
) }}

{% endif %}

{%- endmacro -%}
