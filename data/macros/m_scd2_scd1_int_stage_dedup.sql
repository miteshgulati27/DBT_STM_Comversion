{%- macro m_scd2_scd1_int_stage_dedup(
    in_unique_key,
    in_scd2_cols,
    in_scd1_cols,
    in_order_by_col='EFFECTIVE_DATE',
    in_source_relation=none,
    in_hash_algo='MD5'
) -%}

{#--
    SCD Type 2 / Type 1 Intermediate Stage Deduplication Macro.
    Handles:
    - Deduplication of source records by unique key
    - Hash comparison for SCD2 change detection
    - SCD1 attribute overlay on latest record
    - Row numbering for merge operations
--#}

{%- set scd2_hash_cols = in_scd2_cols | sort | join(', ') -%}
{%- set scd1_hash_cols = in_scd1_cols | sort | join(', ') -%}

WITH source_records AS (
    SELECT
        *,
        {{ in_hash_algo }}(
            COALESCE(CAST({{ in_scd2_cols | join(" AS VARCHAR), '') || '|' || COALESCE(CAST(") }} AS VARCHAR), '')
        ) AS scd2_hash_key,
        {{ in_hash_algo }}(
            COALESCE(CAST({{ in_scd1_cols | join(" AS VARCHAR), '') || '|' || COALESCE(CAST(") }} AS VARCHAR), '')
        ) AS scd1_hash_key
    {% if in_source_relation is not none %}
    FROM {{ in_source_relation }}
    {% else %}
    FROM {{ ref(model.name | replace('_stage_dedup', '')) }}
    {% endif %}
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ in_unique_key }}
            ORDER BY {{ in_order_by_col }} DESC
        ) AS dedup_row_num
    FROM source_records
),

deduped AS (
    SELECT *
    FROM ranked
    WHERE dedup_row_num = 1
),

{#-- Compare against existing target for change detection --#}
{% if m_is_incremental() %}
existing AS (
    SELECT
        {{ in_unique_key }},
        scd2_hash_key AS existing_scd2_hash,
        scd1_hash_key AS existing_scd1_hash
    FROM {{ this }}
    WHERE CURRENT_FLAG = 'Y'
),

change_detected AS (
    SELECT
        d.*,
        CASE
            WHEN e.{{ in_unique_key }} IS NULL THEN 'INSERT'
            WHEN d.scd2_hash_key != e.existing_scd2_hash THEN 'SCD2_UPDATE'
            WHEN d.scd1_hash_key != e.existing_scd1_hash THEN 'SCD1_UPDATE'
            ELSE 'NO_CHANGE'
        END AS change_type
    FROM deduped d
    LEFT JOIN existing e
        ON d.{{ in_unique_key }} = e.{{ in_unique_key }}
)

SELECT *
FROM change_detected
WHERE change_type != 'NO_CHANGE'

{% else %}

final AS (
    SELECT
        *,
        'INSERT' AS change_type
    FROM deduped
)

SELECT * FROM final

{% endif %}

{%- endmacro -%}
