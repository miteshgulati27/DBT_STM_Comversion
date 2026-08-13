{%- macro m_cleansing(in_cleansing_name, in_column_nm) -%}

    {%- if in_cleansing_name == 'VARCHAR_SINGLESPACE' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            ELSE REGEXP_REPLACE(TRIM({{ in_column_nm }}), '\\s+', ' ')
        END
    {%- elif in_cleansing_name == 'VARCHAR_QUESTION' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            WHEN TRIM({{ in_column_nm }}) = '?' THEN NULL
            WHEN TRIM({{ in_column_nm }}) = '??' THEN NULL
            ELSE TRIM({{ in_column_nm }})
        END
    {%- elif in_cleansing_name == 'VARCHAR_NOKEY' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            WHEN UPPER(TRIM({{ in_column_nm }})) = 'NOKEY' THEN NULL
            WHEN UPPER(TRIM({{ in_column_nm }})) = 'NO KEY' THEN NULL
            ELSE TRIM({{ in_column_nm }})
        END
    {%- elif in_cleansing_name == 'VARCHAR_UPPER' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            ELSE UPPER(TRIM({{ in_column_nm }}))
        END
    {%- elif in_cleansing_name == 'VARCHAR_LOWER' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            ELSE LOWER(TRIM({{ in_column_nm }}))
        END
    {%- elif in_cleansing_name == 'VARCHAR_TRIM' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            ELSE TRIM({{ in_column_nm }})
        END
    {%- elif in_cleansing_name == 'NUMBER_ZERO_TO_NULL' -%}
        CASE
            WHEN {{ in_column_nm }} = 0 THEN NULL
            ELSE {{ in_column_nm }}
        END
    {%- elif in_cleansing_name == 'DATE_DEFAULT' -%}
        CASE
            WHEN {{ in_column_nm }} IS NULL THEN '1900-01-01'::DATE
            ELSE {{ in_column_nm }}
        END
    {%- elif in_cleansing_name == 'TIMESTAMP_DEFAULT' -%}
        CASE
            WHEN {{ in_column_nm }} IS NULL THEN '1900-01-01 00:00:00'::TIMESTAMP_NTZ
            ELSE {{ in_column_nm }}
        END
    {%- elif in_cleansing_name == 'BOOLEAN_DEFAULT' -%}
        CASE
            WHEN {{ in_column_nm }} IS NULL THEN FALSE
            ELSE {{ in_column_nm }}
        END
    {%- elif in_cleansing_name == 'VARCHAR_NA' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            WHEN UPPER(TRIM({{ in_column_nm }})) IN ('N/A', 'NA', 'NONE', 'NULL') THEN NULL
            ELSE TRIM({{ in_column_nm }})
        END
    {%- elif in_cleansing_name == 'VARCHAR_DASH' -%}
        CASE
            WHEN TRIM({{ in_column_nm }}) = '' THEN NULL
            WHEN TRIM({{ in_column_nm }}) IN ('-', '--', '---') THEN NULL
            ELSE TRIM({{ in_column_nm }})
        END
    {%- else -%}
        {{ in_column_nm }}
    {%- endif -%}

{%- endmacro -%}
