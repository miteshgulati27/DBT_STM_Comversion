{%- macro m_dh_default_record_upsert(
    in_target_schema,
    in_target_table,
    in_surrogate_key_col,
    in_default_key_value=-1,
    in_default_desc='Unknown'
) -%}

{#--
    Data Hub default record upsert macro.
    Ensures a default/unknown record exists in dimension tables
    for referential integrity with fact tables.

    Arguments:
        in_target_schema: Target schema
        in_target_table: Target table name
        in_surrogate_key_col: Surrogate key column name
        in_default_key_value: Default key value (default: -1)
        in_default_desc: Default description value (default: 'Unknown')
--#}

MERGE INTO {{ in_target_schema }}.{{ in_target_table }} AS tgt
USING (
    SELECT
        {{ in_default_key_value }} AS {{ in_surrogate_key_col }},
        '{{ in_default_desc }}' AS default_description,
        '1900-01-01'::DATE AS EFFECTIVE_DATE,
        '9999-12-31'::DATE AS EXPIRY_DATE,
        'Y' AS CURRENT_FLAG,
        CURRENT_TIMESTAMP() AS DW_INSERT_TIMESTAMP,
        CURRENT_TIMESTAMP() AS DW_UPDATE_TIMESTAMP
) AS src
ON tgt.{{ in_surrogate_key_col }} = src.{{ in_surrogate_key_col }}
WHEN NOT MATCHED THEN
    INSERT ({{ in_surrogate_key_col }}, EFFECTIVE_DATE, EXPIRY_DATE, CURRENT_FLAG, DW_INSERT_TIMESTAMP, DW_UPDATE_TIMESTAMP)
    VALUES (src.{{ in_surrogate_key_col }}, src.EFFECTIVE_DATE, src.EXPIRY_DATE, src.CURRENT_FLAG, src.DW_INSERT_TIMESTAMP, src.DW_UPDATE_TIMESTAMP)

{%- endmacro -%}
