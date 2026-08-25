

{{ config(
    materialized='table'
) 
}}


WITH pc_bopbuilding AS (
    SELECT * FROM {{ source('sources_bop', 'pc_bopbuilding') }}
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
  NOTE: PC_BOPCLASSCODE, PCTL_SWIMMINGPOOLS, PCTL_DIVINGBOARDS,
        PCTL_BOPCONSTRUCTIONTYPE do not exist in this Guidewire instance.
        Columns ClassCodeID, BOPLocation, Building, BasisAmount,
        NumPools, NumDiving, ConstructionType are not present on
        PC_BOPBUILDING. Setting corresponding output columns to NULL.
==========================================================*/

INT_BOPBLDG AS (
    SELECT
        ----------------------------------------------------------
        -- Business Keys
        ----------------------------------------------------------
        'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR) || '-' || 'BOPBuilding' || '-' || CAST(src.FixedID AS VARCHAR)
            AS BOP_CVRBL_KEY,

        'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR)
            AS POL_KEY,

        NULL                        AS POL_LINE_KEY,

        'GWPC' || '-' || 'BOPBuilding'
            AS CVRBL_TYPE_KEY,

        NULL                        AS BOP_CL_CD_KEY,

        NULL                        AS BOP_LOC_KEY,

        NULL                        AS BLDG_KEY,

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
        'BOPBuilding'               AS CVRBL_TYPE_CD,

        CAST(NULL AS INT)           AS BASIS_AMT,

        NULL                        AS CONSTR_TYPE_CD,

        NULL                        AS NUM_DIVING_CD,

        NULL                        AS NUM_POOLS_CD,

        PreferredCoverageCurrency.TYPECODE AS PREFD_COVG_CURR_CD,

        job.CloseDate               AS ETL_ROW_EFF_DTS

    FROM pc_bopbuilding src
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
                FROM pc_bopbuilding srcx
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

INT_BOPBLDG_cleaned AS (
    SELECT
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_CVRBL_KEY') }})  AS BOP_CVRBL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})        AS POL_KEY,
        {{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }}           AS POL_LINE_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CVRBL_TYPE_KEY') }}) AS CVRBL_TYPE_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_CL_CD_KEY') }})  AS BOP_CL_CD_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_LOC_KEY') }})    AS BOP_LOC_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BLDG_KEY') }})       AS BLDG_KEY,
        {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                 AS END_EFF_DT,
        {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                AS END_EXP_DT,
        ETL_END_EFF_DTS,
        ETL_END_EXP_DTS,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}   AS SOURCE_SYSTEM,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }}   AS CVRBL_TYPE_CD,
        {{ m_cleanse('INTEGER_ZERO', 'BASIS_AMT') }}              AS BASIS_AMT,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CONSTR_TYPE_CD') }}  AS CONSTR_TYPE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'NUM_DIVING_CD') }}   AS NUM_DIVING_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'NUM_POOLS_CD') }}    AS NUM_POOLS_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PREFD_COVG_CURR_CD') }} AS PREFD_COVG_CURR_CD,
        ETL_ROW_EFF_DTS
    FROM INT_BOPBLDG
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
    'BASIS_AMT',
    'CONSTR_TYPE_CD',
    'NUM_DIVING_CD',
    'NUM_POOLS_CD',
    'PREFD_COVG_CURR_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'POL_LINE_KEY',
    'CVRBL_TYPE_KEY',
    'BOP_CL_CD_KEY',
    'BOP_LOC_KEY',
    'BLDG_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_BOPBLDG_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}