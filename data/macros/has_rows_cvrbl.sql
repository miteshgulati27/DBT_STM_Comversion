{%- macro has_rows_cvrbl(in_relation, in_coverage_col, in_coverage_value) -%}

{#--
    Checks if a relation has rows matching a specific coverage/variable condition.
    Returns TRUE if matching rows exist, FALSE otherwise.

    Arguments:
        in_relation: The relation (table/view) to check
        in_coverage_col: The column to filter on
        in_coverage_value: The value to filter for
--#}

{%- set query -%}
    SELECT COUNT(*) AS row_count
    FROM {{ in_relation }}
    WHERE {{ in_coverage_col }} = '{{ in_coverage_value }}'
    LIMIT 1
{%- endset -%}

{%- if execute -%}
    {%- set result = run_query(query) -%}
    {%- set row_count = result.columns[0].values()[0] -%}
    {{ return(row_count > 0) }}
{%- else -%}
    {{ return(false) }}
{%- endif -%}

{%- endmacro -%}
