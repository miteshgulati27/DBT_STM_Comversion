
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pcx_ca7modifier AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7modifier') }}
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

pctl_jurisdiction AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_jurisdiction') }}
),

pctl_ca7modifier AS (
    SELECT *
    FROM {{ source('sources_ca', 'pctl_ca7modifier') }}
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

INT_CAMODIFIER AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'CA7Modifier'
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS CA_MOD_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || CAST(src.CommAutoLine AS VARCHAR)
        AS POL_LINE_KEY,

    NULL AS CA_CVRBL_KEY,

    'GWPC'
        || '-'
        || src.PatternCode
        AS MOD_KEY,

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

    'CommercialAutoLine' AS CVRBL_TYPE_CD,

    CASE
        WHEN src.BooleanModifier IS NOT NULL
            THEN CAST(src.BooleanModifier AS VARCHAR)
        WHEN src.DateModifier IS NOT NULL
            THEN CAST(src.DateModifier AS VARCHAR)
        WHEN src.RateModifier IS NOT NULL
            THEN CAST(src.RateModifier AS VARCHAR)
        WHEN src.TypeKeyModifier IS NOT NULL
            THEN src.TypeKeyModifier
    END AS MOD_VAL_TEXT,

    src.PatternCode AS MOD_CD,

    State.TYPECODE AS STATE_CD,

    Subtype.TYPECODE AS SUBTYPE_CD,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pcx_ca7modifier src

INNER JOIN pc_policyperiod polper
    ON polper.ID = src.BranchID

INNER JOIN pc_job job
    ON job.ID = polper.JobID

INNER JOIN pctl_policyperiodstatus status
    ON status.ID = polper.Status

INNER JOIN pctl_jurisdiction State
    ON State.ID = src.State

INNER JOIN pctl_ca7modifier Subtype
    ON Subtype.ID = src.Subtype

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
            FROM pcx_ca7modifier srcx
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

INT_CAMODIFIER_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_MOD_KEY') }})               AS CA_MOD_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                  AS POL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }})             AS POL_LINE_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CA_CVRBL_KEY') }}              AS CA_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'MOD_KEY') }})                  AS MOD_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                           AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                          AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}             AS SOURCE_SYSTEM,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }}             AS CVRBL_TYPE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'MOD_VAL_TEXT') }}              AS MOD_VAL_TEXT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'MOD_CD') }}                    AS MOD_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STATE_CD') }}                  AS STATE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SUBTYPE_CD') }}                AS SUBTYPE_CD,
    ETL_ROW_EFF_DTS
FROM INT_CAMODIFIER

)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'CA_MOD_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD',
    'MOD_VAL_TEXT',
    'MOD_CD',
    'STATE_CD',
    'SUBTYPE_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'POL_LINE_KEY',
    'CA_CVRBL_KEY',
    'MOD_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CAMODIFIER_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
