
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pc_bopratefactor AS (
    SELECT *
    FROM {{ source('sources_bop', 'pc_bopratefactor') }}
),

pc_policyperiod AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_policyperiod') }}
),

pc_job AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_job') }}
),

pctl_policyperiodstatus AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_policyperiodstatus') }}
),

etl_control_parm AS (
    SELECT
        MAX(start_extract_date) AS start_extract_date,
        MAX(end_extract_date)   AS end_extract_date
    FROM {{ ref('etl_control_parm') }}
),

/*==========================================================
  Business Mapping
==========================================================*/

INT_BOPRATEFACTOR AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'BOPRateFactor'
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS BOP_MOD_RF_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'BOPModifier'
        || '-'
        || CAST(src.BOPModifier AS VARCHAR)
        AS BOP_MOD_KEY,

    CAST(
        COALESCE(src.EffectiveDate, polper.PeriodStart)
        AS DATE
    ) AS END_EFF_DT,

    CAST(
        COALESCE(src.ExpirationDate, polper.PeriodEnd)
        AS DATE
    ) AS END_EXP_DT,

    TO_TIMESTAMP_NTZ(
        COALESCE(src.EffectiveDate, polper.PeriodStart)
    ) AS ETL_END_EFF_DTS,

    TO_TIMESTAMP_NTZ(
        COALESCE(src.ExpirationDate, polper.PeriodEnd)
    ) AS ETL_END_EXP_DTS,

    'GWPC' AS SOURCE_SYSTEM,

    ----------------------------------------------------------
    -- Business Attributes
    ----------------------------------------------------------

    'BusinessOwnersLine' AS CVRBL_TYPE_CD,

    src.PatternCode AS RF_CD,

    src.Assessment AS ASSESS_RATE,

    src.Justification AS JUST_TEXT,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pc_bopratefactor src

INNER JOIN pc_policyperiod polper
    ON polper.ID = src.BranchID

INNER JOIN pc_job job
    ON job.ID = polper.JobID

INNER JOIN pctl_policyperiodstatus status
    ON status.ID = polper.Status

CROSS JOIN etl_control_parm ecp

WHERE
    status.TYPECODE = 'Bound'

    AND job.CloseDate <= ecp.end_extract_date

    {% if is_incremental() %}
    AND job.CloseDate > ecp.start_extract_date
    {% endif %}

    AND (
        COALESCE(src.EffectiveDate, polper.PeriodStart)
        <> COALESCE(src.ExpirationDate, polper.PeriodEnd)

        OR NOT EXISTS (
            SELECT 1
            FROM pc_bopratefactor srcx
            INNER JOIN pc_policyperiod polperx
                ON polperx.ID = srcx.BranchID
            WHERE srcx.BranchID = src.BranchID
              AND srcx.FixedID = src.FixedID
              AND COALESCE(srcx.EffectiveDate, polperx.PeriodStart)
                  <> COALESCE(srcx.ExpirationDate, polperx.PeriodEnd)
        )
    )

),

/*==========================================================
  Cleansing
==========================================================*/

INT_BOPRATEFACTOR_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_MOD_RF_KEY') }})           AS BOP_MOD_RF_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                  AS POL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_MOD_KEY') }})              AS BOP_MOD_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                           AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                          AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}             AS SOURCE_SYSTEM,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }}             AS CVRBL_TYPE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'RF_CD') }}                     AS RF_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'ASSESS_RATE') }}                      AS ASSESS_RATE,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'JUST_TEXT') }}                  AS JUST_TEXT,
    ETL_ROW_EFF_DTS
FROM INT_BOPRATEFACTOR

)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'BOP_MOD_RF_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD',
    'RF_CD',
    'ASSESS_RATE',
    'JUST_TEXT'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'BOP_MOD_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_BOPRATEFACTOR_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
