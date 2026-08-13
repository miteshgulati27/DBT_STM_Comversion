{%- macro m_scd2_scd1_marts(
    in_unique_key,
    in_scd2_cols,
    in_scd1_cols,
    in_source_relation,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG',
    in_surrogate_key_col=none
) -%}

{#--
    SCD Type 2 / Type 1 Marts layer macro.
    Produces the final dimension table output with proper SCD handling.
    Handles both Type 2 (versioned history) and Type 1 (overwrite) attributes.

    Arguments:
        in_unique_key: Natural/business key column
        in_scd2_cols: List of SCD Type 2 columns (tracked history)
        in_scd1_cols: List of SCD Type 1 columns (overwrite on all versions)
        in_source_relation: Source staging relation
        in_effective_date_col: Effective date column
        in_expiry_date_col: Expiry date column
        in_current_flag_col: Current record flag column
        in_surrogate_key_col: Optional surrogate key column name
--#}

{% if m_is_incremental() %}

{#-- Get the latest SCD1 values for each business key --#}
WITH latest_scd1 AS (
    SELECT
        {{ in_unique_key }},
        {% for col in in_scd1_cols %}
        {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM {{ in_source_relation }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY {{ in_unique_key }}
        ORDER BY {{ in_effective_date_col }} DESC
    ) = 1
),

{#-- Apply SCD1 updates to all existing records for changed keys --#}
scd1_updates AS (
    SELECT
        tgt.{{ in_unique_key }},
        {% for col in in_scd2_cols %}
        tgt.{{ col }},
        {% endfor %}
        {% for col in in_scd1_cols %}
        ls.{{ col }},
        {% endfor %}
        tgt.{{ in_effective_date_col }},
        tgt.{{ in_expiry_date_col }},
        tgt.{{ in_current_flag_col }}
    FROM {{ this }} tgt
    INNER JOIN latest_scd1 ls
        ON tgt.{{ in_unique_key }} = ls.{{ in_unique_key }}
),

{#-- New SCD2 inserts --#}
new_records AS (
    SELECT
        src.{{ in_unique_key }},
        {% for col in in_scd2_cols %}
        src.{{ col }},
        {% endfor %}
        {% for col in in_scd1_cols %}
        src.{{ col }},
        {% endfor %}
        src.{{ in_effective_date_col }},
        COALESCE(src.{{ in_expiry_date_col }}, '9999-12-31'::DATE) AS {{ in_expiry_date_col }},
        CASE
            WHEN COALESCE(src.{{ in_expiry_date_col }}, '9999-12-31'::DATE) >= CURRENT_DATE()
            THEN 'Y' ELSE 'N'
        END AS {{ in_current_flag_col }}
    FROM {{ in_source_relation }} src
    WHERE src.change_type IN ('INSERT', 'SCD2_UPDATE')
)

SELECT * FROM scd1_updates
UNION ALL
SELECT * FROM new_records

{% else %}

SELECT
    {% if in_surrogate_key_col is not none %}
    {{ hash([in_unique_key, in_effective_date_col]) }} AS {{ in_surrogate_key_col }},
    {% endif %}
    {{ in_unique_key }},
    {% for col in in_scd2_cols %}
    {{ col }},
    {% endfor %}
    {% for col in in_scd1_cols %}
    {{ col }},
    {% endfor %}
    {{ in_effective_date_col }},
    COALESCE({{ in_expiry_date_col }}, '9999-12-31'::DATE) AS {{ in_expiry_date_col }},
    CASE
        WHEN COALESCE({{ in_expiry_date_col }}, '9999-12-31'::DATE) >= CURRENT_DATE()
        THEN 'Y' ELSE 'N'
    END AS {{ in_current_flag_col }},
    CURRENT_TIMESTAMP() AS DW_INSERT_TIMESTAMP,
    CURRENT_TIMESTAMP() AS DW_UPDATE_TIMESTAMP
FROM {{ in_source_relation }}

{% endif %}

{%- endmacro -%}
