{#-
    Macro: m_cleansing
    Purpose: Generic column cleansing macro. Pass a cleansing rule name and
    a column name, and it returns the corresponding CASE/expression logic.
-#}
{%- macro m_cleansing(in_cleansing_name, in_column_nm) -%}

{%- set final_return -%}

    {%- if in_cleansing_name == 'VARCHAR_SINGLESPACE' -%}

        (case when {{ in_column_nm }} is null or TRIM({{ in_column_nm }})='' then ' ' else TRIM({{ in_column_nm }}) end)

    {%- elif in_cleansing_name == 'VARCHAR_QUESTION' -%}

        (case when {{ in_column_nm }} is null or TRIM({{ in_column_nm }})='' then '?' else TRIM({{ in_column_nm }}) end)

    {%- elif in_cleansing_name == 'VARCHAR_NOKEY' -%}

        (case when {{ in_column_nm }} is null or TRIM({{ in_column_nm }})='' then 'NOKEY' else TRIM({{ in_column_nm }}) end)

    {%- elif in_cleansing_name == 'VARCHAR_NA_LOWERCASE' -%}

        (case when {{ in_column_nm }} is null or TRIM({{ in_column_nm }})='' then 'n/a' else TRIM({{ in_column_nm }}) end)

    {%- elif in_cleansing_name == 'VARCHAR_NA' -%}

        (case when {{ in_column_nm }} is null or {{ in_column_nm }}='' then 'N/A' else TRIM({{ in_column_nm }}) end)

    {%- elif in_cleansing_name == 'NUMERIC_ZERO' -%}

        (case when {{ in_column_nm }} is null then 0 else {{ in_column_nm }} end)

    {%- elif in_cleansing_name == 'VARCHAR_FLAG_UNKNOWN' -%}

        (case when {{ in_column_nm }} is null or {{ in_column_nm }}='' then 'U' else TRIM({{ in_column_nm }}) end)

    {%- elif in_cleansing_name == 'VARCHAR_FLAG_Y_N_U' -%}

        (case when TRIM({{ in_column_nm }})='true' then 'Y' when TRIM({{ in_column_nm }})='false' then 'N' else 'U' end)

    {%- elif in_cleansing_name == 'DATE_LOW' -%}

        (case when is_date(to_variant({{ in_column_nm }})) = FALSE then to_date('01/01/1900','MM/DD/YYYY')
        else {{ in_column_nm }}
        end)

    {%- elif in_cleansing_name == 'DATE_HIGH' -%}

        (case when is_date(to_variant({{ in_column_nm }})) = FALSE then to_date('12/31/9000','MM/DD/YYYY')
        else {{ in_column_nm }}
        end)

    {%- elif in_cleansing_name == 'TIMESTAMP_NTZ_LOW' -%}

        (case when is_timestamp_ntz(to_variant({{ in_column_nm }})) = FALSE then to_timestamp('01/01/1900 00:00:00','MM/DD/YYYY HH24:MI:SS')
        else {{ in_column_nm }}
        end)

    {%- elif in_cleansing_name == 'TIMESTAMP_NTZ_HIGH' -%}

        (case when is_timestamp_ntz(to_variant({{ in_column_nm }})) = FALSE then to_timestamp('12/31/9000 00:00:00','MM/DD/YYYY HH24:MI:SS')
        else {{ in_column_nm }}
        end)

    {%- else -%}

        {{ in_column_nm }}

    {%- endif -%}

{%- endset -%}

{{ return(final_return) }}

{%- endmacro -%}