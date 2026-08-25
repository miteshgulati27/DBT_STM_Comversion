
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pcx_ca7garagesvc AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7garagesvc') }}
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

pctl_currency AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_currency') }}
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

INT_CAGARAGESVC AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'GarageSvc'
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS CA_CVRBL_KEY,

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

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'Jurisdiction'
        || '-'
        || CAST(src.Jurisdiction AS VARCHAR)
        AS OWNING_CVRBL_KEY,

    'GWPC'
        || '-'
        || 'GarageSvc'
        AS CVRBL_TYPE_KEY,

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

    'GarageSvc' AS CVRBL_TYPE_CD,

    State.TYPECODE AS STATE_CD,

    src.AddressLine1 AS ADDR_LINE1,

    src.AddressLine2 AS ADDR_LINE2,

    src.City AS CITY,

    src.State_Addr AS STATE_ADDR_CD,

    src.PostalCode AS ZIP_CD,

    src.County AS COUNTY,

    src.Country AS CNTRY_CD,

    src.Description AS DESC_TEXT,

    src.NumEmployees AS NUM_EMPLOYEES,

    src.NumPartTimeEmployees AS NUM_PART_TIME_EMPL,

    src.NumLifts AS NUM_LIFTS,

    PreferredCoverageCurrency.TYPECODE
        AS PREFD_COVG_CURR_CD,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pcx_ca7garagesvc src

INNER JOIN pc_policyperiod polper
    ON polper.ID = src.BranchID

INNER JOIN pc_job job
    ON job.ID = polper.JobID

INNER JOIN pctl_policyperiodstatus status
    ON status.ID = polper.Status

INNER JOIN pctl_jurisdiction State
    ON State.ID = src.State

INNER JOIN pctl_currency PreferredCoverageCurrency
    ON PreferredCoverageCurrency.ID = src.PreferredCoverageCurrency

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
            FROM pcx_ca7garagesvc srcx
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

INT_CAGARAGESVC_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_CVRBL_KEY') }})             AS CA_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                  AS POL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }})             AS POL_LINE_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'OWNING_CVRBL_KEY') }})         AS OWNING_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CVRBL_TYPE_KEY') }})           AS CVRBL_TYPE_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                           AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                          AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}             AS SOURCE_SYSTEM,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }}             AS CVRBL_TYPE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STATE_CD') }}                  AS STATE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'ADDR_LINE1') }}                AS ADDR_LINE1,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'ADDR_LINE2') }}                AS ADDR_LINE2,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CITY') }}                      AS CITY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STATE_ADDR_CD') }}             AS STATE_ADDR_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'ZIP_CD') }}                    AS ZIP_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'COUNTY') }}                    AS COUNTY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CNTRY_CD') }}                  AS CNTRY_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'DESC_TEXT') }}                  AS DESC_TEXT,
    {{ m_cleanse('INTEGER_ZERO', 'NUM_EMPLOYEES') }}                    AS NUM_EMPLOYEES,
    {{ m_cleanse('INTEGER_ZERO', 'NUM_PART_TIME_EMPL') }}               AS NUM_PART_TIME_EMPL,
    {{ m_cleanse('INTEGER_ZERO', 'NUM_LIFTS') }}                        AS NUM_LIFTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'PREFD_COVG_CURR_CD') }}        AS PREFD_COVG_CURR_CD,
    ETL_ROW_EFF_DTS
FROM INT_CAGARAGESVC

)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'CA_CVRBL_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD',
    'STATE_CD',
    'ADDR_LINE1',
    'ADDR_LINE2',
    'CITY',
    'STATE_ADDR_CD',
    'ZIP_CD',
    'COUNTY',
    'CNTRY_CD',
    'DESC_TEXT',
    'NUM_EMPLOYEES',
    'NUM_PART_TIME_EMPL',
    'NUM_LIFTS',
    'PREFD_COVG_CURR_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'POL_LINE_KEY',
    'OWNING_CVRBL_KEY',
    'CVRBL_TYPE_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CAGARAGESVC_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
