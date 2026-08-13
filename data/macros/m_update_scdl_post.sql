{%- macro m_update_scdl_post(
    in_target_schema,
    in_target_table,
    in_unique_key,
    in_effective_date_col='EFFECTIVE_DATE',
    in_expiry_date_col='EXPIRY_DATE',
    in_current_flag_col='CURRENT_FLAG'
) -%}

{#--
    Post-load SCD (Slowly Changing Dimension) update macro.
    Recalculates expiry dates and current flags after new records
    have been inserted into the target table.

    Arguments:
        in_target_schema: Target schema name
        in_target_table: Target table name
        in_unique_key: Business key column
        in_effective_date_col: Effective date column
        in_expiry_date_col: Expiry date column
        in_current_flag_col: Current flag column
--#}

{#-- Step 1: Recalculate expiry dates based on next effective date --#}
UPDATE {{ in_target_schema }}.{{ in_target_table }} tgt
SET
    tgt.{{ in_expiry_date_col }} = DATEADD(DAY, -1, nxt.next_eff_dt),
    tgt.{{ in_current_flag_col }} = 'N',
    tgt.DW_UPDATE_TIMESTAMP = CURRENT_TIMESTAMP()
FROM (
    SELECT
        {{ in_unique_key }},
        {{ in_effective_date_col }},
        LEAD({{ in_effective_date_col }}) OVER (
            PARTITION BY {{ in_unique_key }}
            ORDER BY {{ in_effective_date_col }}
        ) AS next_eff_dt
    FROM {{ in_target_schema }}.{{ in_target_table }}
) nxt
WHERE tgt.{{ in_unique_key }} = nxt.{{ in_unique_key }}
    AND tgt.{{ in_effective_date_col }} = nxt.{{ in_effective_date_col }}
    AND nxt.next_eff_dt IS NOT NULL
    AND tgt.{{ in_expiry_date_col }} != DATEADD(DAY, -1, nxt.next_eff_dt);

{#-- Step 2: Set current flag on the latest record per key --#}
UPDATE {{ in_target_schema }}.{{ in_target_table }} tgt
SET
    tgt.{{ in_current_flag_col }} = 'Y',
    tgt.{{ in_expiry_date_col }} = '9999-12-31'::DATE,
    tgt.DW_UPDATE_TIMESTAMP = CURRENT_TIMESTAMP()
FROM (
    SELECT
        {{ in_unique_key }},
        MAX({{ in_effective_date_col }}) AS max_eff_dt
    FROM {{ in_target_schema }}.{{ in_target_table }}
    GROUP BY {{ in_unique_key }}
) latest
WHERE tgt.{{ in_unique_key }} = latest.{{ in_unique_key }}
    AND tgt.{{ in_effective_date_col }} = latest.max_eff_dt
    AND tgt.{{ in_current_flag_col }} != 'Y'

{%- endmacro -%}
