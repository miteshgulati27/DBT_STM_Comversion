{%- macro m_lel_json_part(
    in_json_column,
    in_json_path,
    in_output_type='VARCHAR',
    in_alias=none
) -%}

{#--
    Extracts a specific part/path from a JSON column (LEL - Lateral Element).
    Provides typed extraction from VARIANT/JSON columns.

    Arguments:
        in_json_column: The JSON/VARIANT column to extract from
        in_json_path: The JSON path to extract (e.g., 'name', 'address.city')
        in_output_type: Cast type for the output (default: VARCHAR)
        in_alias: Optional column alias for the output
--#}

    {{ in_json_column }}:{{ in_json_path }}::{{ in_output_type }}
    {%- if in_alias is not none %} AS {{ in_alias }}{% endif -%}

{%- endmacro -%}
