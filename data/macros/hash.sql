{%- macro hash(in_columns, in_algo='MD5') -%}

{#--
    Generates a hash of the provided columns concatenated with a delimiter.

    Arguments:
        in_columns: List of column names to hash
        in_algo: Hash algorithm to use (MD5, SHA1, SHA2_256). Default: MD5
--#}

{%- if in_algo == 'MD5' -%}
    MD5(
{%- elif in_algo == 'SHA1' -%}
    SHA1(
{%- elif in_algo == 'SHA2_256' -%}
    SHA2(
{%- else -%}
    MD5(
{%- endif -%}
        {% for col in in_columns %}
        COALESCE(CAST({{ col }} AS VARCHAR), '')
        {%- if not loop.last %} || '|' || {% endif %}
        {% endfor %}
    )
{%- if in_algo == 'SHA2_256' -%}, 256){%- endif -%}

{%- endmacro -%}
