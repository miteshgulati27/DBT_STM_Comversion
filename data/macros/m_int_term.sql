{%- macro m_int_term(
    in_source_name,
    in_source_table,
    in_term_key,
    in_term_cols,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG',
    in_delete_flag_col=none,
    in_filter_condition=none,
    in_incremental_col=none,
    in_incremental_lookback=3
) -%}

{#--
    Term-processing macro for intermediate layer.
    Handles SCD Type 2 term logic including:
    - Effective/Expiry date management
    - Current flag assignment
    - Deduplication of term records
    - Incremental processing support
--#}

WITH source_data AS (
    SELECT
        {{ in_term_key }},
        {% for col in in_term_cols %}
        {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %},
        {{ in_effective_date_col }},
        {{ in_expiry_date_col }},
        {{ in_current_flag_col }}
        {% if in_delete_flag_col is not none %}
        , {{ in_delete_flag_col }}
        {% endif %}
    FROM {{ source(in_source_name, in_source_table) }}
    WHERE 1=1
    {% if in_filter_condition is not none %}
        AND {{ in_filter_condition }}
    {% endif %}
    {% if m_is_incremental() and in_incremental_col is not none %}
        AND {{ in_incremental_col }} >= DATEADD(DAY, -{{ in_incremental_lookback }}, CURRENT_DATE())
    {% endif %}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ in_term_key }}, {{ in_effective_date_col }}
            ORDER BY {{ in_effective_date_col }} DESC, {{ in_expiry_date_col }} DESC
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
        COALESCE(
            {{ in_expiry_date_col }},
            LEAD(DATEADD(DAY, -1, {{ in_effective_date_col }})) OVER (
                PARTITION BY {{ in_term_key }}
                ORDER BY {{ in_effective_date_col }}
            ),
            '9999-12-31'::DATE
        ) AS {{ in_expiry_date_col }},
        CASE
            WHEN {{ in_expiry_date_col }} = '9999-12-31'::DATE
                OR {{ in_expiry_date_col }} >= CURRENT_DATE()
            THEN 'Y'
            ELSE 'N'
        END AS {{ in_current_flag_col }}
        {% if in_delete_flag_col is not none %}
        , {{ in_delete_flag_col }}
        {% endif %}
    FROM deduped
    WHERE rn = 1
)

SELECT * FROM term_records
{% if in_delete_flag_col is not none %}
WHERE COALESCE({{ in_delete_flag_col }}, 'N') != 'Y'
{% endif %}

{%- endmacro -%}
