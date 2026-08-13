{%- macro m_meta_key_cols(
    in_relation,
    in_key_type='PK'
) -%}

{#--
    Metadata macro: Retrieves key columns for a given relation.
    Queries information_schema or metadata tables to identify
    primary key, unique key, or foreign key columns.

    Arguments:
        in_relation: The relation to retrieve key metadata for
        in_key_type: Key type - 'PK' (primary), 'UK' (unique), 'FK' (foreign)
                     Default: 'PK'
--#}

{%- if execute -%}

    {%- set query -%}
        SELECT
            COLUMN_NAME,
            ORDINAL_POSITION
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
            AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
            AND tc.TABLE_NAME = kcu.TABLE_NAME
        WHERE tc.TABLE_SCHEMA = '{{ in_relation.schema | upper }}'
            AND tc.TABLE_NAME = '{{ in_relation.identifier | upper }}'
            {% if in_key_type == 'PK' %}
            AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
            {% elif in_key_type == 'UK' %}
            AND tc.CONSTRAINT_TYPE = 'UNIQUE'
            {% elif in_key_type == 'FK' %}
            AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
            {% endif %}
        ORDER BY kcu.ORDINAL_POSITION
    {%- endset -%}

    {%- set results = run_query(query) -%}
    {%- set key_cols = results.columns[0].values() -%}
    {{ return(key_cols) }}

{%- else -%}
    {{ return([]) }}
{%- endif -%}

{%- endmacro -%}
