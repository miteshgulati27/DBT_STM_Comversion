
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pc_policyline AS (
    SELECT *
    FROM {{ source('sources_ca', 'pc_policyline') }}
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

pctl_currency AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_currency') }}
),

pctl_policyline AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_policyline') }}
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

INT_CAPOLLINE AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS CA_POL_LINE_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

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

    src.NumVehicles AS NUM_VEHICLES,

    CASE
        WHEN src.Fleet = 1 THEN 'Y'
        WHEN src.Fleet = 0 THEN 'N'
        ELSE NULL
    END AS FLEET_FL,

    src.PatternCode AS PAT_CD,

    PreferredCoverageCurrency.TYPECODE
        AS PREFD_COVG_CURR_CD,

    Subtype.TYPECODE
        AS SUBTYPE_CD,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pc_policyline src

INNER JOIN pc_policyperiod polper
    ON polper.ID = src.BranchID

INNER JOIN pc_job job
    ON job.ID = polper.JobID

INNER JOIN pctl_policyperiodstatus status
    ON status.ID = polper.Status

INNER JOIN pctl_currency PreferredCoverageCurrency
    ON PreferredCoverageCurrency.ID = src.PreferredCoverageCurrency

INNER JOIN pctl_policyline Subtype
    ON Subtype.ID = src.Subtype

CROSS JOIN etl_control_parm ecp

WHERE
    status.TYPECODE = 'Bound'

    AND Subtype.TYPECODE = 'CommercialAutoLine'

    AND job.CloseDate <= ecp.end_extract_date

    {% if is_incremental() %}
    AND job.CloseDate > ecp.start_extract_date
    {% endif %}

    AND (
        COALESCE(src.EffectiveDate, polper.PeriodStart)
        <> COALESCE(src.ExpirationDate, polper.PeriodEnd)

        OR NOT EXISTS (
            SELECT 1
            FROM pc_policyline srcx
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

INT_CAPOLLINE_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_POL_LINE_KEY') }})          AS CA_POL_LINE_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                  AS POL_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                           AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                          AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}             AS SOURCE_SYSTEM,
    {{ m_cleanse('INTEGER_ZERO', 'NUM_VEHICLES') }}                     AS NUM_VEHICLES,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'FLEET_FL') }}                  AS FLEET_FL,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'PAT_CD') }}                    AS PAT_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'PREFD_COVG_CURR_CD') }}        AS PREFD_COVG_CURR_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SUBTYPE_CD') }}                AS SUBTYPE_CD,
    ETL_ROW_EFF_DTS
FROM INT_CAPOLLINE

)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'CA_POL_LINE_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'NUM_VEHICLES',
    'FLEET_FL',
    'PAT_CD',
    'PREFD_COVG_CURR_CD',
    'SUBTYPE_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CAPOLLINE_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
