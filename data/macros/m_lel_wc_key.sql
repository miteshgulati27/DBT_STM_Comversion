{%- macro m_lel_wc_key(
    in_key_columns,
    in_separator='|',
    in_alias='WC_KEY'
) -%}

{#--
    Generates a composite key (Wildcard Key) by concatenating multiple columns.
    Used in LEL (Lateral Element) processing for key generation.

    Arguments:
        in_key_columns: List of columns to concatenate into a key
        in_separator: Separator between key parts (default: '|')
        in_alias: Output column alias (default: 'WC_KEY')
--#}

    CONCAT_WS('{{ in_separator }}',
        {% for col in in_key_columns %}
        COALESCE(CAST({{ col }} AS VARCHAR), '')
        {%- if not loop.last %},{% endif %}
        {% endfor %}
    ) AS {{ in_alias }}

{%- endmacro -%}
