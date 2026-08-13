{%- macro has_rows(in_relation) -%}

{#--
    Checks if a relation has any rows.
    Returns TRUE if at least one row exists, FALSE otherwise.

    Arguments:
        in_relation: The relation (table/view) to check
--#}

{%- set query -%}
    SELECT COUNT(*) AS row_count FROM {{ in_relation }} LIMIT 1
{%- endset -%}

{%- if execute -%}
    {%- set result = run_query(query) -%}
    {%- set row_count = result.columns[0].values()[0] -%}
    {{ return(row_count > 0) }}
{%- else -%}
    {{ return(false) }}
{%- endif -%}

{%- endmacro -%}
