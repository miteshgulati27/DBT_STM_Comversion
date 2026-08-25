
{{ config(
    materialized='table'
) }}


WITH pcx_bopsbllocation AS (
    SELECT * FROM {{ source('sources_bop', 'pcx_bopsbllocation') }}
),

pc_policyperiod AS (
    SELECT * FROM {{ source('sources_common', 'pc_policyperiod') }}
),

pc_job AS (
    SELECT * FROM {{ source('sources_common', 'pc_job') }}
),

pctl_policyperiodstatus AS (
    SELECT * FROM {{ source('sources_common', 'pctl_policyperiodstatus') }}
),

pctl_currency AS (
    SELECT * FROM {{ source('sources_common', 'pctl_currency') }}
),

etl_control_parm AS (
    SELECT
        MAX(start_extract_date) AS start_extract_date,
        MAX(end_extract_date)   AS end_extract_date
    FROM {{ ref('etl_control_parm') }}
),

/*==========================================================
  Business Mapping
  NOTE: PC_BOPLOCATION does not exist in this Guidewire instance.
        The actual source table is PCX_BOPSBLLOCATION.
        PC_RISKCLASS does not exist either.
        Columns Location, CityLimits, PrincipalOpsDesc, RiskClassID
        are not present on PCX_BOPSBLLOCATION.
        Setting LOC_KEY, RISK_CL_KEY, CITY_LIMITS_FL, PRIN_OPS_DESC to NULL.
        POL_LINE_KEY uses src."_LINE" (the BOPLine FK equivalent).
==========================================================*/

INT_BOPLOC AS (
    SELECT
        ----------------------------------------------------------
        -- Business Keys
        ----------------------------------------------------------
        'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR) || '-' || 'BOPLocation' || '-' || CAST(src.FixedID AS VARCHAR)
            AS BOP_CVRBL_KEY,

        'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR)
            AS POL_KEY,

        'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR) || '-' || CAST(src."_LINE" AS VARCHAR)
            AS POL_LINE_KEY,

        'GWPC' || '-' || 'BOPLocation'
            AS CVRBL_TYPE_KEY,

        NULL                        AS LOC_KEY,

        NULL                        AS RISK_CL_KEY,

        CAST(
            COALESCE(src.EffectiveDate, polper.PeriodStart) AS DATE
        )                           AS END_EFF_DT,

        CAST(
            COALESCE(src.ExpirationDate, polper.PeriodEnd) AS DATE
        )                           AS END_EXP_DT,

        TO_TIMESTAMP_NTZ(
            COALESCE(src.EffectiveDate, polper.PeriodStart)
        )                           AS ETL_END_EFF_DTS,

        TO_TIMESTAMP_NTZ(
            COALESCE(src.ExpirationDate, polper.PeriodEnd)
        )                           AS ETL_END_EXP_DTS,

        'GWPC'                      AS SOURCE_SYSTEM,

        ----------------------------------------------------------
        -- Business Attributes
        ----------------------------------------------------------
        'BOPLocation'               AS CVRBL_TYPE_CD,

        NULL                        AS CITY_LIMITS_FL,

        PreferredCoverageCurrency.TYPECODE AS PREFD_COVG_CURR_CD,

        NULL                        AS PRIN_OPS_DESC,

        job.CloseDate               AS ETL_ROW_EFF_DTS

    FROM pcx_bopsbllocation src
    INNER JOIN pc_policyperiod polper
        ON polper.ID = src.BranchID
    INNER JOIN pc_job job
        ON job.ID = polper.JobID
    INNER JOIN pctl_policyperiodstatus status
        ON status.ID = polper.Status
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
                FROM pcx_bopsbllocation srcx
                INNER JOIN pc_policyperiod polperx
                    ON polperx.ID = srcx.BranchID
                WHERE srcx.BranchID = src.BranchID
                  AND srcx.FixedID  = src.FixedID
                  AND COALESCE(srcx.EffectiveDate, polperx.PeriodStart)
                      <> COALESCE(srcx.ExpirationDate, polperx.PeriodEnd)
            )
        )
),

/*==========================================================
  Cleansing
==========================================================*/

INT_BOPLOC_cleaned AS (
    SELECT
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_CVRBL_KEY') }})  AS BOP_CVRBL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})        AS POL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }})   AS POL_LINE_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CVRBL_TYPE_KEY') }}) AS CVRBL_TYPE_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'LOC_KEY') }})        AS LOC_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'RISK_CL_KEY') }})    AS RISK_CL_KEY,
        {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                 AS END_EFF_DT,
        {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                AS END_EXP_DT,
        ETL_END_EFF_DTS,
        ETL_END_EXP_DTS,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}   AS SOURCE_SYSTEM,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }}   AS CVRBL_TYPE_CD,
        {{ m_cleanse('VARCHAR_BOOLEAN', 'CITY_LIMITS_FL') }}      AS CITY_LIMITS_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PREFD_COVG_CURR_CD') }} AS PREFD_COVG_CURR_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PRIN_OPS_DESC') }}   AS PRIN_OPS_DESC,
        ETL_ROW_EFF_DTS
    FROM INT_BOPLOC
)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'BOP_CVRBL_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD',
    'CITY_LIMITS_FL',
    'PREFD_COVG_CURR_CD',
    'PRIN_OPS_DESC'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'POL_LINE_KEY',
    'CVRBL_TYPE_KEY',
    'LOC_KEY',
    'RISK_CL_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_BOPLOC_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}