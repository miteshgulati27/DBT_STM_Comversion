
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pcx_ca7ppschedcovitem AS (
    SELECT * FROM {{ source('sources_ca', 'pcx_ca7ppschedcovitem') }}
),

parent AS (
    SELECT * FROM {{ source('sources_ca', 'pcx_ca7privatepassengercov') }}
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

etl_control_parm AS (
    SELECT
        MAX(start_extract_date) AS start_extract_date,
        MAX(end_extract_date)   AS end_extract_date
    FROM {{ ref('etl_control_parm') }}
),

/*==========================================================
  Business Mapping
==========================================================*/

INT_CA_SI_PRIVATEPASSENGER_COVGSI AS (

SELECT

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'PrivatePassengerCovgSI'
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS CA_CVRBL_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

    NULL AS POL_LINE_KEY,

    CASE
        WHEN parent.PrivatePassenger IS NULL THEN NULL
        ELSE 'GWPC'
            || '-'
            || CAST(polper.PeriodID AS VARCHAR)
            || '-'
            || 'PrivatePassenger'
            || '-'
            || CAST(parent.PrivatePassenger AS VARCHAR)
    END AS OWNING_CVRBL_KEY,

    'GWPC' || '-' || 'PrivatePassengerCovgSI' AS CVRBL_TYPE_KEY,

    CASE
        WHEN src.ScheduleCoverage IS NULL THEN NULL
        ELSE 'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR) || '-' || CAST(src.ScheduleCoverage AS VARCHAR)
    END AS CA_COVG_KEY,

    CASE
        WHEN src.NamedInsured IS NULL THEN NULL
        ELSE 'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR) || '-' || CAST(src.NamedInsured AS VARCHAR)
    END AS POL_PARTY_KEY,

    CASE
        WHEN src.PolicyLocation IS NULL THEN NULL
        ELSE 'GWPC' || '-' || CAST(polper.PeriodID AS VARCHAR) || '-' || CAST(src.PolicyLocation AS VARCHAR)
    END AS LOC_KEY,

    NULL AS CA_ADDL_INTRST_KEY,

    NULL AS CA_COND_KEY,

    NULL AS CA_EXCL_KEY,

    CAST(COALESCE(src.EffectiveDate, polper.PeriodStart) AS DATE) AS END_EFF_DT,
    CAST(COALESCE(src.ExpirationDate, polper.PeriodEnd) AS DATE) AS END_EXP_DT,
    TO_TIMESTAMP_NTZ(COALESCE(src.EffectiveDate, polper.PeriodStart)) AS ETL_END_EFF_DTS,
    TO_TIMESTAMP_NTZ(COALESCE(src.ExpirationDate, polper.PeriodEnd)) AS ETL_END_EXP_DTS,
    'GWPC' AS SOURCE_SYSTEM,

    'PrivatePassengerCovgSI' AS CVRBL_TYPE_CD,

    src.ScheduleNumber AS SCHED_NO,
    src.TypeKeyCol1 AS TYPE_KEY_COL_1,
    src.TypeKeyCol2 AS TYPE_KEY_COL_2,
    src.StringCol1 AS STR_COL_1,
    src.StringCol2 AS STR_COL_2,
    src.StringCol3 AS STR_COL_3,
    src.StringCol4 AS STR_COL_4,
    src.DateCol1 AS DT_COL_1_DTS,
    src.IntCol1 AS INT_COL_1,
    src.PosIntCol1 AS POS_INT_COL_1,
    src.NonNegativeIntCol1 AS NON_NEG_INT_1,
    src.NonNegativeIntCol2 AS NON_NEG_INT_2,
    src.NonNegativeIntCol3 AS NON_NEG_INT_3,
    src.NonNegativeIntCol4 AS NON_NEG_INT_4,
    CASE WHEN src.BoolCol1 = 1 THEN 'Y' WHEN src.BoolCol1 = 0 THEN 'N' ELSE NULL END AS BOOL_COL_1_FL,
    CASE WHEN src.BoolCol2 = 1 THEN 'Y' WHEN src.BoolCol2 = 0 THEN 'N' ELSE NULL END AS BOOL_COL_2_FL,
    src.OptionCol1 AS OPT_COL_1,
    src.OptionCol2 AS OPT_COL_2,
    src.OptionCol3 AS OPT_COL_3,
    src.OptionCol4 AS OPT_COL_4,
    src.OptionCol5 AS OPT_COL_5,
    src.OptionCol6 AS OPT_COL_6,
    src.DecimalCol1 AS DECIMAL_COL_1,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pcx_ca7ppschedcovitem src

INNER JOIN parent
    ON parent.FixedID = src.ScheduleCoverage
    AND parent.BranchID = src.BranchID
    AND COALESCE(src.EffectiveDate, polper.PeriodStart) >= COALESCE(parent.EffectiveDate, polper.PeriodStart)
    AND COALESCE(src.EffectiveDate, polper.PeriodStart) < COALESCE(parent.ExpirationDate, polper.PeriodEnd)

INNER JOIN pc_policyperiod polper ON polper.ID = src.BranchID
INNER JOIN pc_job job ON job.ID = polper.JobID
INNER JOIN pctl_policyperiodstatus status ON status.ID = polper.Status
CROSS JOIN etl_control_parm ecp

WHERE
    status.TYPECODE = 'Bound'
    AND job.CloseDate <= ecp.end_extract_date
    {% if is_incremental() %}
    AND job.CloseDate > ecp.start_extract_date
    {% endif %}
    AND (
        COALESCE(src.EffectiveDate, polper.PeriodStart) <> COALESCE(src.ExpirationDate, polper.PeriodEnd)
        OR NOT EXISTS (
            SELECT 1 FROM pcx_ca7ppschedcovitem srcx
            INNER JOIN pc_policyperiod polperx ON polperx.ID = srcx.BranchID
            WHERE srcx.BranchID = src.BranchID AND srcx.FixedID = src.FixedID
              AND COALESCE(srcx.EffectiveDate, polperx.PeriodStart) <> COALESCE(srcx.ExpirationDate, polperx.PeriodEnd)
        )
    )
),

/*==========================================================
  Cleansing
==========================================================*/

INT_CA_SI_PRIVATEPASSENGER_COVGSI_cleaned AS (
SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_CVRBL_KEY') }}) AS CA_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }}) AS POL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }}) AS POL_LINE_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'OWNING_CVRBL_KEY') }}) AS OWNING_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CVRBL_TYPE_KEY') }}) AS CVRBL_TYPE_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_COVG_KEY') }}) AS CA_COVG_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_PARTY_KEY') }}) AS POL_PARTY_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'LOC_KEY') }}) AS LOC_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CA_ADDL_INTRST_KEY') }} AS CA_ADDL_INTRST_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_COND_KEY') }}) AS CA_COND_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_EXCL_KEY') }}) AS CA_EXCL_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }} AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }} AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }} AS SOURCE_SYSTEM,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }} AS CVRBL_TYPE_CD,
    {{ m_cleanse('INTEGER_ZERO', 'SCHED_NO') }} AS SCHED_NO,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'TYPE_KEY_COL_1') }} AS TYPE_KEY_COL_1,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'TYPE_KEY_COL_2') }} AS TYPE_KEY_COL_2,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STR_COL_1') }} AS STR_COL_1,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STR_COL_2') }} AS STR_COL_2,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STR_COL_3') }} AS STR_COL_3,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STR_COL_4') }} AS STR_COL_4,
    {{ m_cleanse('TIMESTAMP', 'DT_COL_1_DTS') }} AS DT_COL_1_DTS,
    {{ m_cleanse('INTEGER_ZERO', 'INT_COL_1') }} AS INT_COL_1,
    {{ m_cleanse('INTEGER_ZERO', 'POS_INT_COL_1') }} AS POS_INT_COL_1,
    {{ m_cleanse('INTEGER_ZERO', 'NON_NEG_INT_1') }} AS NON_NEG_INT_1,
    {{ m_cleanse('INTEGER_ZERO', 'NON_NEG_INT_2') }} AS NON_NEG_INT_2,
    {{ m_cleanse('INTEGER_ZERO', 'NON_NEG_INT_3') }} AS NON_NEG_INT_3,
    {{ m_cleanse('INTEGER_ZERO', 'NON_NEG_INT_4') }} AS NON_NEG_INT_4,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'BOOL_COL_1_FL') }} AS BOOL_COL_1_FL,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'BOOL_COL_2_FL') }} AS BOOL_COL_2_FL,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'OPT_COL_1') }} AS OPT_COL_1,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'OPT_COL_2') }} AS OPT_COL_2,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'OPT_COL_3') }} AS OPT_COL_3,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'OPT_COL_4') }} AS OPT_COL_4,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'OPT_COL_5') }} AS OPT_COL_5,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'OPT_COL_6') }} AS OPT_COL_6,
    {{ m_cleanse('NUMERIC_ZERO', 'DECIMAL_COL_1') }} AS DECIMAL_COL_1,
    ETL_ROW_EFF_DTS
FROM INT_CA_SI_PRIVATEPASSENGER_COVGSI
)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = ['CA_CVRBL_KEY', 'END_EFF_DT'] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS', 'ETL_END_EXP_DTS', 'END_EXP_DT', 'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD', 'SCHED_NO', 'TYPE_KEY_COL_1', 'TYPE_KEY_COL_2',
    'STR_COL_1', 'STR_COL_2', 'STR_COL_3', 'STR_COL_4',
    'DT_COL_1_DTS', 'INT_COL_1', 'POS_INT_COL_1',
    'NON_NEG_INT_1', 'NON_NEG_INT_2', 'NON_NEG_INT_3', 'NON_NEG_INT_4',
    'BOOL_COL_1_FL', 'BOOL_COL_2_FL',
    'OPT_COL_1', 'OPT_COL_2', 'OPT_COL_3', 'OPT_COL_4', 'OPT_COL_5', 'OPT_COL_6',
    'DECIMAL_COL_1'
] -%}

{%- set scd1_cols = [
    'POL_KEY', 'POL_LINE_KEY', 'OWNING_CVRBL_KEY', 'CVRBL_TYPE_KEY',
    'CA_COVG_KEY', 'POL_PARTY_KEY', 'LOC_KEY', 'CA_ADDL_INTRST_KEY',
    'CA_COND_KEY', 'CA_EXCL_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CA_SI_PRIVATEPASSENGER_COVGSI_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
