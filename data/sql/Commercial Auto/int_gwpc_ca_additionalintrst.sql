
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pc_addlinterestdetail AS (
    SELECT *
    FROM {{ source('sources_ca', 'pc_addlinterestdetail') }}
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

pctl_addlinterestdetail AS (
    SELECT *
    FROM {{ source('sources_ca', 'pctl_addlinterestdetail') }}
),

pctl_additionalinteresttype AS (
    SELECT *
    FROM {{ source('sources_ca', 'pctl_additionalinteresttype') }}
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

INT_CA_ADDL_INTRST AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || CAST(src.FixedID AS VARCHAR)
        AS CA_ADDL_INTRST_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

    NULL AS CA_CVRBL_KEY,

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

    ait.TYPECODE AS ADDL_INTRST_TYPE_CD,

    CASE
        WHEN src.CertRequired = 1 THEN 'Y'
        WHEN src.CertRequired = 0 THEN 'N'
        ELSE NULL
    END AS CERT_REQ_FL,

    src.ContractNumber AS CONT_NO,

    sub.TYPECODE AS SUBTYPE_CD,

    job.CloseDate AS ETL_ROW_EFF_DTS

FROM pc_addlinterestdetail src

INNER JOIN pc_policyperiod polper
    ON polper.ID = src.BranchID

INNER JOIN pc_job job
    ON job.ID = polper.JobID

INNER JOIN pctl_policyperiodstatus status
    ON status.ID = polper.Status

LEFT JOIN pctl_additionalinteresttype ait
    ON ait.ID = src.AdditionalInterestType

INNER JOIN pctl_addlinterestdetail sub
    ON sub.ID = src.Subtype

CROSS JOIN etl_control_parm ecp

WHERE
    status.TYPECODE = 'Bound'

    AND sub.TYPECODE IN ('CA7AddlInterest')

    AND job.CloseDate <= ecp.end_extract_date

    {% if is_incremental() %}
    AND job.CloseDate > ecp.start_extract_date
    {% endif %}

    AND (
        COALESCE(src.EffectiveDate, polper.PeriodStart)
        <> COALESCE(src.ExpirationDate, polper.PeriodEnd)

        OR NOT EXISTS (
            SELECT 1
            FROM pc_addlinterestdetail srcx
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

INT_CA_ADDL_INTRST_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_ADDL_INTRST_KEY') }})       AS CA_ADDL_INTRST_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                  AS POL_KEY,
    {{ m_cleanse('VARCHAR_NOKEY', 'CA_CVRBL_KEY') }}                    AS CA_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_PARTY_KEY') }})            AS POL_PARTY_KEY,
    {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }}                           AS END_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }}                          AS END_EXP_DT,
    ETL_END_EFF_DTS,
    ETL_END_EXP_DTS,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}             AS SOURCE_SYSTEM,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'ADDL_INTRST_TYPE_CD') }}       AS ADDL_INTRST_TYPE_CD,
    (
        CASE
            WHEN UPPER(TRIM(CAST(CERT_REQ_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
            WHEN UPPER(TRIM(CAST(CERT_REQ_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
            ELSE 'U'
        END
    ) AS CERT_REQ_FL,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CONT_NO') }}                   AS CONT_NO,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SUBTYPE_CD') }}                AS SUBTYPE_CD,
    ETL_ROW_EFF_DTS
FROM INT_CA_ADDL_INTRST

)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'CA_ADDL_INTRST_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'ADDL_INTRST_TYPE_CD',
    'CERT_REQ_FL',
    'CONT_NO',
    'SUBTYPE_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'CA_CVRBL_KEY',
    'POL_PARTY_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CA_ADDL_INTRST_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}
