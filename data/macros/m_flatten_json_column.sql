{%- macro m_flatten_json_column(
    in_source_relation,
    in_json_column,
    in_key_column,
    in_output_alias='flattened'
) -%}

{#--
    Flattens a JSON column into rows, extracting key-value pairs.

    Arguments:
        in_source_relation: Source table/view containing the JSON column
        in_json_column: Name of the JSON/VARIANT column to flatten
        in_key_column: Primary key column(s) to maintain row identity
        in_output_alias: Alias for the flattened output (default: 'flattened')
--#}

SELECT
    src.{{ in_key_column }},
    {{ in_output_alias }}.KEY AS attribute_name,
    {{ in_output_alias }}.VALUE::VARCHAR AS attribute_value,
    {{ in_output_alias }}.INDEX AS attribute_index,
    {{ in_output_alias }}.PATH AS attribute_path
FROM {{ in_source_relation }} src,
LATERAL FLATTEN(INPUT => src.{{ in_json_column }}, OUTER => TRUE) {{ in_output_alias }}

{%- endmacro -%}
