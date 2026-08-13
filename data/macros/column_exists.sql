{%- macro column_exists(in_relation, in_column_name) -%}

{#--
    Checks if a column exists in a given relation.
    Returns TRUE if the column exists, FALSE otherwise.

    Arguments:
        in_relation: The relation (table/view) to check
        in_column_name: The column name to look for
--#}

{%- set columns = adapter.get_columns_in_relation(in_relation) -%}
{%- set column_names = columns | map(attribute='name') | map('upper') | list -%}

{%- if in_column_name | upper in column_names -%}
    {{ return(true) }}
{%- else -%}
    {{ return(false) }}
{%- endif -%}

{%- endmacro -%}
