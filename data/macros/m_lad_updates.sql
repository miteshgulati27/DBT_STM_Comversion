{%- macro m_lad_updates(
    in_target_schema,
    in_target_table,
    in_source_relation,
    in_unique_key,
    in_scd2_cols,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG'
) -%}

{#--
    Load Audit Delta - Updates macro.
    Expires existing current records and inserts new versions
    when SCD2 attribute changes are detected.

    Arguments:
        in_target_schema: Target schema name
        in_target_table: Target table name
        in_source_relation: Source relation reference
        in_unique_key: Unique business key column
        in_scd2_cols: List of SCD2 columns to compare for changes
        in_effective_date_col: Effective date column
        in_expiry_date_col: Expiry date column
        in_current_flag_col: Current flag column
--#}

{#-- Step 1: Expire current records that have changed --#}
UPDATE {{ in_target_schema }}.{{ in_target_table }} tgt
SET
    tgt.{{ in_expiry_date_col }} = DATEADD(DAY, -1, src.{{ in_effective_date_col }}),
    tgt.{{ in_current_flag_col }} = 'N',
    tgt.DW_UPDATE_TIMESTAMP = CURRENT_TIMESTAMP()
FROM {{ in_source_relation }} src
WHERE tgt.{{ in_unique_key }} = src.{{ in_unique_key }}
    AND tgt.{{ in_current_flag_col }} = 'Y'
    AND (
        {% for col in in_scd2_cols %}
        COALESCE(CAST(tgt.{{ col }} AS VARCHAR), '') != COALESCE(CAST(src.{{ col }} AS VARCHAR), '')
        {%- if not loop.last %} OR {% endif %}
        {% endfor %}
    );

{#-- Step 2: Insert new version records --#}
INSERT INTO {{ in_target_schema }}.{{ in_target_table }}
SELECT
    src.*,
    CURRENT_TIMESTAMP() AS DW_INSERT_TIMESTAMP,
    CURRENT_TIMESTAMP() AS DW_UPDATE_TIMESTAMP
FROM {{ in_source_relation }} src
INNER JOIN {{ in_target_schema }}.{{ in_target_table }} tgt
    ON src.{{ in_unique_key }} = tgt.{{ in_unique_key }}
    AND tgt.{{ in_current_flag_col }} = 'N'
    AND tgt.DW_UPDATE_TIMESTAMP = CURRENT_TIMESTAMP()

{%- endmacro -%}
