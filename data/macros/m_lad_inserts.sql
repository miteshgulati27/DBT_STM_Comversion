{%- macro m_lad_inserts(
    in_target_schema,
    in_target_table,
    in_source_relation,
    in_unique_key,
    in_columns,
    in_effective_date_col='EFFECTIVE_DATE',
    in_current_flag_col='CURRENT_FLAG'
) -%}

{#--
    Load Audit Delta - Inserts macro.
    Identifies new records from source that do not exist in target.
    Used in conjunction with m_lad_updates for SCD processing.

    Arguments:
        in_target_schema: Target schema name
        in_target_table: Target table name
        in_source_relation: Source relation reference
        in_unique_key: Unique business key column
        in_columns: List of columns to insert
        in_effective_date_col: Effective date column
        in_current_flag_col: Current flag column
--#}

INSERT INTO {{ in_target_schema }}.{{ in_target_table }} (
    {% for col in in_columns %}
    {{ col }},
    {% endfor %}
    {{ in_effective_date_col }},
    {{ in_current_flag_col }},
    DW_INSERT_TIMESTAMP,
    DW_UPDATE_TIMESTAMP
)
SELECT
    {% for col in in_columns %}
    src.{{ col }},
    {% endfor %}
    src.{{ in_effective_date_col }},
    'Y' AS {{ in_current_flag_col }},
    CURRENT_TIMESTAMP() AS DW_INSERT_TIMESTAMP,
    CURRENT_TIMESTAMP() AS DW_UPDATE_TIMESTAMP
FROM {{ in_source_relation }} src
LEFT JOIN {{ in_target_schema }}.{{ in_target_table }} tgt
    ON src.{{ in_unique_key }} = tgt.{{ in_unique_key }}
    AND tgt.{{ in_current_flag_col }} = 'Y'
WHERE tgt.{{ in_unique_key }} IS NULL

{%- endmacro -%}
