
{{ config(
    materialized='table'
) }}


WITH pc_addlinterestdetail AS (
    SELECT * FROM {{ source('sources_bop', 'pc_addlinterestdetail') }}
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

pctl_addlinterestdetail AS (
    SELECT * FROM {{ source('sources_bop', 'pctl_addlinterestdetail') }}
),

pctl_additionalinteresttype AS (
    SELECT * FROM {{ source('sources_bop', 'pctl_additionalinteresttype') }}
),

etl_control_parm AS (
    SELECT
        MAX(start_extract_date) AS start_extract_date,
        MAX(end_extract_date)   AS end_extract_date
    FROM {{ ref('etl_control_parm') }}
),

/*==========================================================
  Anti-join: identify rows with effective date spans
==========================================================*/

has_effective AS (
    SELECT DISTINCT srcx.BRANCHID, srcx.FIXEDID
    FROM pc_addlinterestdetail srcx
    INNER JOIN pc_policyperiod polperx ON polperx.ID = srcx.BRANCHID
    WHERE COALESCE(srcx.EFFECTIVEDATE, polperx.PERIODSTART)
          <> COALESCE(srcx.EXPIRATIONDATE, polperx.PERIODEND)
),

/*==========================================================
  Business Mapping
==========================================================*/

INT_BOP_ADDL_INTRST AS (
    SELECT DISTINCT
        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR) || '-' || CAST(src.FIXEDID AS VARCHAR)
            AS BOP_ADDL_INTRST_KEY,

        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR)
            AS POL_KEY,

        NULL AS BOP_CVRBL_KEY,

        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR) || '-' || CAST(src.POLICYADDLINTEREST AS VARCHAR)
            AS POL_PARTY_KEY,

        CAST(COALESCE(src.EFFECTIVEDATE, polper.PERIODSTART) AS DATE) AS END_EFF_DT,

        CAST(COALESCE(src.EXPIRATIONDATE, polper.PERIODEND) AS DATE) AS END_EXP_DT,

        TO_TIMESTAMP_NTZ(COALESCE(src.EFFECTIVEDATE, polper.PERIODSTART)) AS ETL_END_EFF_DTS,

        TO_TIMESTAMP_NTZ(COALESCE(src.EXPIRATIONDATE, polper.PERIODEND)) AS ETL_END_EXP_DTS,

        'GWPC' AS SOURCE_SYSTEM,

        NULL AS CVRBL_TYPE_CD,

        ait.TYPECODE AS ADDL_INTRST_TYPE_CD,

        CASE
            WHEN src.CERTREQUIRED = 1 THEN 'Y'
            WHEN src.CERTREQUIRED = 0 THEN 'N'
            ELSE NULL
        END AS CERT_REQ_FL,

        src.CONTRACTNUMBER AS CONT_NO,

        sub.TYPECODE AS SUBTYPE_CD,

        job.CLOSEDATE AS ETL_ROW_EFF_DTS

    FROM pc_addlinterestdetail src
    JOIN pc_policyperiod polper
        ON polper.ID = src.BRANCHID
    JOIN pc_job job
        ON job.ID = polper.JOBID
    JOIN pctl_policyperiodstatus status
        ON status.ID = polper.STATUS
    LEFT JOIN pctl_additionalinteresttype ait
        ON ait.ID = src.ADDITIONALINTERESTTYPE
    JOIN pctl_addlinterestdetail sub
        ON sub.ID = src.SUBTYPE
    LEFT JOIN has_effective he
        ON he.BRANCHID = src.BRANCHID AND he.FIXEDID = src.FIXEDID
    CROSS JOIN etl_control_parm ecp
    WHERE status.TYPECODE = 'Bound'
      AND sub.TYPECODE IN ('BOPBldgAddlInterest')
      AND (
          COALESCE(src.EFFECTIVEDATE, polper.PERIODSTART)
          <> COALESCE(src.EXPIRATIONDATE, polper.PERIODEND)
          OR he.BRANCHID IS NULL
      )
      AND job.CLOSEDATE <= ecp.end_extract_date
      {% if is_incremental() %}
      AND job.CLOSEDATE > ecp.start_extract_date
      {% endif %}
),

/*==========================================================
  Cleansing
==========================================================*/

INT_BOP_ADDL_INTRST_cleaned AS (
    SELECT
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'BOP_ADDL_INTRST_KEY') }}) AS BOP_ADDL_INTRST_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }}) AS POL_KEY,
        {{ m_cleanse('VARCHAR_NOKEY', 'BOP_CVRBL_KEY') }} AS BOP_CVRBL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_PARTY_KEY') }}) AS POL_PARTY_KEY,
        {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }} AS END_EFF_DT,
        {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }} AS END_EXP_DT,
        ETL_END_EFF_DTS,
        ETL_END_EXP_DTS,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }} AS SOURCE_SYSTEM,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }} AS CVRBL_TYPE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'ADDL_INTRST_TYPE_CD') }} AS ADDL_INTRST_TYPE_CD,
        (
            CASE
                WHEN UPPER(TRIM(CAST(CERT_REQ_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(CERT_REQ_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS CERT_REQ_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CONT_NO') }} AS CONT_NO,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SUBTYPE_CD') }} AS SUBTYPE_CD,
        ETL_ROW_EFF_DTS
    FROM INT_BOP_ADDL_INTRST
)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'BOP_ADDL_INTRST_KEY',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'ETL_END_EFF_DTS',
    'ETL_END_EXP_DTS',
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD',
    'ADDL_INTRST_TYPE_CD',
    'CERT_REQ_FL',
    'CONT_NO',
    'SUBTYPE_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'BOP_CVRBL_KEY',
    'POL_PARTY_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_BOP_ADDL_INTRST_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}