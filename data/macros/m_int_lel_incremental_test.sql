{%- macro m_int_lel_incremental_test(
    in_source_relation,
    in_target_relation,
    in_unique_key,
    in_incremental_col,
    in_incremental_lookback=3
) -%}

{#--
    Incremental test macro for intermediate LEL (Lateral Element) models.
    Validates that incremental processing captured all expected changes.
    Compares source changes within the lookback window against target.

    Arguments:
        in_source_relation: Source relation reference
        in_target_relation: Target relation reference
        in_unique_key: Unique business key column
        in_incremental_col: Column used for incremental detection
        in_incremental_lookback: Days to look back (default: 3)
--#}

WITH source_changes AS (
    SELECT
        {{ in_unique_key }},
        {{ in_incremental_col }},
        COUNT(*) AS src_record_count
    FROM {{ in_source_relation }}
    WHERE {{ in_incremental_col }} >= DATEADD(DAY, -{{ in_incremental_lookback }}, CURRENT_DATE())
    GROUP BY {{ in_unique_key }}, {{ in_incremental_col }}
),

target_records AS (
    SELECT
        {{ in_unique_key }},
        {{ in_incremental_col }},
        COUNT(*) AS tgt_record_count
    FROM {{ in_target_relation }}
    WHERE {{ in_incremental_col }} >= DATEADD(DAY, -{{ in_incremental_lookback }}, CURRENT_DATE())
    GROUP BY {{ in_unique_key }}, {{ in_incremental_col }}
),

missing_in_target AS (
    SELECT
        s.{{ in_unique_key }},
        s.{{ in_incremental_col }},
        'MISSING_IN_TARGET' AS test_failure
    FROM source_changes s
    LEFT JOIN target_records t
        ON s.{{ in_unique_key }} = t.{{ in_unique_key }}
    WHERE t.{{ in_unique_key }} IS NULL
),

count_mismatch AS (
    SELECT
        s.{{ in_unique_key }},
        s.{{ in_incremental_col }},
        'COUNT_MISMATCH' AS test_failure
    FROM source_changes s
    INNER JOIN target_records t
        ON s.{{ in_unique_key }} = t.{{ in_unique_key }}
    WHERE s.src_record_count != t.tgt_record_count
)

SELECT test_failure, COUNT(*) AS failure_count
FROM (
    SELECT test_failure FROM missing_in_target
    UNION ALL
    SELECT test_failure FROM count_mismatch
) failures
GROUP BY test_failure

{%- endmacro -%}
