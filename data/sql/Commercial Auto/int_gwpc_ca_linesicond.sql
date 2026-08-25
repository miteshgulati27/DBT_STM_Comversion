
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pcx_ca7linesicond AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7linesicond') }}
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

INT_CALINESICOND AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'CA7LineSICond'
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS CA_LINE_SI_COND_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || 'CA7Cond'
        || '-'
        || CAST(src.CA7Condition AS VARCHAR)
        AS CA_COND_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || CAST(src.PolicyAddlInterest AS VARCHAR)
        AS POL_PARTY_KEY,

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

    src.ConditionValue AS COND_VALUE_TEXT,

    src.ConditionCode AS COND_CD,

    src.ConditionType AS COND_TYPE_CD,

    src.FirstName AS FIRST_NAME,

    src.LastName AS LAST_NAME,

    CAST(src.DateOfBirth AS DATE) AS DOB_DT,

    src.Gender AS GENDER_CD,

    src.LicenseNumber AS LICENSE_NO,

    src.LicenseState AS LICENSE_STATE_CD,

    src.Relationship AS RELATIONSHIP_CD,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pcx_ca7linesicond src

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
            FROM pcx_ca7linesicond srcx
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

INT_CALINESICOND_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_LINE_SI_COND_KEY') }})      AS CA_LINE_SI_COND_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                  AS POL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_COND_KEY') }})              AS CA_COND_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_PARTY_KEY') }})            AS POL_PARTY_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                           AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                          AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}             AS SOURCE_SYSTEM,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'COND_VALUE_TEXT') }}           AS COND_VALUE_TEXT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'COND_CD') }}                   AS COND_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'COND_TYPE_CD') }}              AS COND_TYPE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'FIRST_NAME') }}                AS FIRST_NAME,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'LAST_NAME') }}                 AS LAST_NAME,
    {{ m_cleanse('DATE_LOW', 'DOB_DT') }}                               AS DOB_DT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'GENDER_CD') }}                 AS GENDER_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'LICENSE_NO') }}                AS LICENSE_NO,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'LICENSE_STATE_CD') }}          AS LICENSE_STATE_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'RELATIONSHIP_CD') }}           AS RELATIONSHIP_CD,
    ETL_ROW_EFF_DTS
FROM INT_CALINESICOND

)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'CA_LINE_SI_COND_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'COND_VALUE_TEXT',
    'COND_CD',
    'COND_TYPE_CD',
    'FIRST_NAME',
    'LAST_NAME',
    'DOB_DT',
    'GENDER_CD',
    'LICENSE_NO',
    'LICENSE_STATE_CD',
    'RELATIONSHIP_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'CA_COND_KEY',
    'POL_PARTY_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CALINESICOND_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
