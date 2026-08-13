

{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pcx_ca7publictransport AS (
    SELECT * FROM {{ source('sources_ca', 'pcx_ca7publictransport') }}
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

pctl_lengthoflease AS (
    SELECT * FROM {{ source('sources_ca', 'pctl_lengthoflease') }}
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
  Anti-join: identify rows with effective date spans
==========================================================*/

has_effective AS (
    SELECT DISTINCT srcx.BRANCHID, srcx.FIXEDID
    FROM pcx_ca7publictransport srcx
    INNER JOIN pc_policyperiod polperx ON polperx.ID = srcx.BRANCHID
    WHERE CAST(COALESCE(srcx.EFFECTIVEDATE, polperx.PERIODSTART) AS DATE)
          <> CAST(COALESCE(srcx.EXPIRATIONDATE, polperx.PERIODEND) AS DATE)
),

/*==========================================================
  Business Mapping
==========================================================*/

INT_CA_VEH_PUBTRNSP AS (
    SELECT DISTINCT
        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR) || '-' || 'PublicTransport' || '-' || CAST(capubtrnsp.FIXEDID AS VARCHAR)
            AS CA_CVRBL_KEY,

        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR)
            AS POL_KEY,

        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR) || '-' || CAST(capubtrnsp.COMMAUTOLINE AS VARCHAR)
            AS POL_LINE_KEY,

        NULL AS OWNING_CVRBL_KEY,

        'GWPC' || '-' || 'PublicTransport'
            AS CVRBL_TYPE_KEY,

        'GWPC' || '-' || CAST(polper.PERIODID AS VARCHAR) || '-' || CAST(capubtrnsp.LOCATION AS VARCHAR)
            AS GARAGE_LOC_KEY,

        job.CLOSEDATE AS ROW_PROC_DTS,

        CAST(COALESCE(capubtrnsp.EFFECTIVEDATE, polper.PERIODSTART) AS DATE) AS END_EFF_DT,

        CAST(COALESCE(capubtrnsp.EXPIRATIONDATE, polper.PERIODEND) AS DATE) AS END_EXP_DT,

        'GWPC' AS SOURCE_SYSTEM,

        'PublicTransport' AS CVRBL_TYPE_CD,

        capubtrnsp.CA7VIN AS VEH_ID_NO,

        capubtrnsp.CA7MAKE AS MAKE_NAME,

        capubtrnsp.CA7MODEL AS MODEL_NAME,

        capubtrnsp.CA7YEAR AS MODEL_YR,

        capubtrnsp.CA7VEHICLENUMBER AS VEH_NO,

        capubtrnsp.CA7ORIGINALCOSTNEW AS ORIG_COST_NEW_AMT,

        capubtrnsp.CA7STATEDAMOUNT AS STATED_AMT,

        capubtrnsp.CA7UNITNUMBER AS UNIT_NO,

        NULL AS LIC_JURS_CD,

        NULL AS LIC_PLATE,

        NULL AS LEASE_OR_RENT_FL,

        lenoflease.TYPECODE AS LEN_OF_LEASE_CD,

        capubtrnsp.CA7PRIMARYCLASSCODE AS CL_CD,

        CASE
            WHEN capubtrnsp.CA7FLEET = 'Yes' THEN 'Y'
            WHEN capubtrnsp.CA7FLEET = 'No' THEN 'N'
            ELSE NULL
        END AS FLEET_FL,

        NULL AS LESSOR_AN_EMP_FL,

        NULL AS PRVT_PSNGR_OPER_EXPER_CD,

        NULL AS PRVT_PSNGR_USE_CD,

        NULL AS PRVT_PSNGR_TYPE_CD,

        NULL AS BUS_USE_CL_CD,

        NULL AS GVW_NO,

        NULL AS TRUCK_RADIUS_CL_CD,

        NULL AS TRUCK_SEC_CL_CD,

        capubtrnsp.CA7SECONDARYCLASSCODE AS SEC_CL_CD,

        NULL AS SIZE_CL_CD,

        NULL AS TRLR_HOW_USED_CD,

        capubtrnsp.CA7FARTHESTTERMINALZONE AS FAR_TERM_ZONE,

        capubtrnsp.CA7GARAGINGZONE AS GARAGING_ZONE,

        capubtrnsp.CA7NUMBEROFDAYSSCHOOLYEAR AS DAYS_SCHL_YR_CNT,

        CASE
            WHEN capubtrnsp.CA7SCHOOLBUSPRORATION = 'Yes' THEN 'Y'
            WHEN capubtrnsp.CA7SCHOOLBUSPRORATION = 'No' THEN 'N'
            ELSE NULL
        END AS SCHL_BUS_PRORATION_FL,

        capubtrnsp.CA7SEATINGCAPACITY AS SEATING_CPCTY_CD,

        capubtrnsp.CA7TYPE AS PUB_TRNSP_TYPE_CD,

        capubtrnsp.CA7RADIUSCLASS AS PUB_TRNSP_RADIUS_CL_CD,

        NULL AS SPCL_VEH_CL_CD,

        NULL AS ENGINE_SIZE_CD,

        NULL AS GROSS_RECEIPTS_AMT,

        NULL AS NON_OWNED_AUTOS_FL,

        NULL AS DAYS_VEH_LEASED_CNT,

        NULL AS FCTRY_TST_EMP_CNT,

        NULL AS REPO_AUTOS_CNT,

        NULL AS PHYS_DMG_CLASS_CD,

        NULL AS SUPP_TYPE_CD,

        NULL AS COST_HIRE_FOR_COLL_AMT,

        NULL AS COST_HIRE_FOR_LIAB_AMT,

        NULL AS COST_HIRE_FOR_EXCS_LIAB_AMT,

        NULL AS COST_HIRE_FOR_OTC_AMT,

        NULL AS SPCL_VEH_TYPE_CD,

        NULL AS REG_USE_FL,

        curr.TYPECODE AS CURR_CD,

        capubtrnsp.CA7ZIPCODE AS ZIP_CD,

        capubtrnsp.CA7ZIPCODEOVERRIDE AS ZIP_CD_OVERRIDE,

        capubtrnsp.CA7TERRITORY AS TERR,

        capubtrnsp.CA7GARAGINGLOCATION AS GARAGE_LOC,

        NULL AS TRNSP_PCT_TEXT,

        capubtrnsp.CA7SAFETYSCORE AS SAFETY_SCORE,

        CASE
            WHEN capubtrnsp.CA7SAFETYSCOREDISCOUNTAPPLIES = 'Yes' THEN 'Y'
            WHEN capubtrnsp.CA7SAFETYSCOREDISCOUNTAPPLIES = 'No' THEN 'N'
            ELSE NULL
        END AS SAFETY_SCORE_DISC_APPLIES_FL,

        NULL AS TELEMATICS_DISC_APPLIES_FL,

        NULL AS USED_AS_TNC_OR_ON_DEMAND_CD,

        CASE
            WHEN capubtrnsp.CA7MECHANICALLIFT = 'Yes' THEN 'Y'
            WHEN capubtrnsp.CA7MECHANICALLIFT = 'No' THEN 'N'
            ELSE NULL
        END AS MECHANICAL_LIFT_FL,

        capubtrnsp.CA7PUBLICTRANSPORTATIONGROUP AS PUB_TRNSP_GRP_CD,

        CASE
            WHEN capubtrnsp.CA7TRANSPORTPUBLICPASSENGERSFO = 'Yes' THEN 'Y'
            WHEN capubtrnsp.CA7TRANSPORTPUBLICPASSENGERSFO = 'No' THEN 'N'
            ELSE NULL
        END AS TRNSP_PUB_PSNGR_FOR_COMP_FL,

        NULL AS AUTO_RENTED_TO_OTHR_CARR_FL,

        NULL AS VEH_INDC_CD

    FROM pcx_ca7publictransport capubtrnsp
    JOIN pc_policyperiod polper
        ON polper.ID = capubtrnsp.BRANCHID
    JOIN pc_job job
        ON job.ID = polper.JOBID
    JOIN pctl_policyperiodstatus status
        ON status.ID = polper.STATUS
    LEFT JOIN pctl_lengthoflease lenoflease
        ON lenoflease.ID = capubtrnsp.LENGTHOFLEASE
    LEFT JOIN pctl_currency curr
        ON curr.ID = capubtrnsp.PREFERREDCOVERAGECURRENCY
    LEFT JOIN has_effective he
        ON he.BRANCHID = capubtrnsp.BRANCHID AND he.FIXEDID = capubtrnsp.FIXEDID
    CROSS JOIN etl_control_parm ecp
    WHERE status.TYPECODE = 'Bound'
      AND (
          CAST(COALESCE(capubtrnsp.EFFECTIVEDATE, polper.PERIODSTART) AS DATE)
          <> CAST(COALESCE(capubtrnsp.EXPIRATIONDATE, polper.PERIODEND) AS DATE)
          OR he.BRANCHID IS NOT NULL
      )
      AND job.CLOSEDATE <= ecp.end_extract_date
      {% if is_incremental() %}
      AND job.CLOSEDATE > ecp.start_extract_date
      {% endif %}
),

/*==========================================================
  Cleansing
==========================================================*/

INT_CA_VEH_PUBTRNSP_cleaned AS (
    SELECT
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_CVRBL_KEY') }}) AS CA_CVRBL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }}) AS POL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }}) AS POL_LINE_KEY,
        {{ m_cleanse('VARCHAR_NOKEY', 'OWNING_CVRBL_KEY') }} AS OWNING_CVRBL_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CVRBL_TYPE_KEY') }}) AS CVRBL_TYPE_KEY,
        UPPER({{ m_cleanse('VARCHAR_NOKEY', 'GARAGE_LOC_KEY') }}) AS GARAGE_LOC_KEY,
        ROW_PROC_DTS,
        {{ m_cleanse('DATE_LOW', 'END_EFF_DT') }} AS END_EFF_DT,
        {{ m_cleanse('DATE_HIGH', 'END_EXP_DT') }} AS END_EXP_DT,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }} AS SOURCE_SYSTEM,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }} AS CVRBL_TYPE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'VEH_ID_NO') }} AS VEH_ID_NO,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'MAKE_NAME') }} AS MAKE_NAME,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'MODEL_NAME') }} AS MODEL_NAME,
        MODEL_YR,
        VEH_NO,
        ORIG_COST_NEW_AMT,
        STATED_AMT,
        UNIT_NO,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'LIC_JURS_CD') }} AS LIC_JURS_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'LIC_PLATE') }} AS LIC_PLATE,
        (
            CASE
                WHEN UPPER(TRIM(CAST(LEASE_OR_RENT_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(LEASE_OR_RENT_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS LEASE_OR_RENT_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'LEN_OF_LEASE_CD') }} AS LEN_OF_LEASE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CL_CD') }} AS CL_CD,
        (
            CASE
                WHEN UPPER(TRIM(CAST(FLEET_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(FLEET_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS FLEET_FL,
        (
            CASE
                WHEN UPPER(TRIM(CAST(LESSOR_AN_EMP_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(LESSOR_AN_EMP_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS LESSOR_AN_EMP_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PRVT_PSNGR_OPER_EXPER_CD') }} AS PRVT_PSNGR_OPER_EXPER_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PRVT_PSNGR_USE_CD') }} AS PRVT_PSNGR_USE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PRVT_PSNGR_TYPE_CD') }} AS PRVT_PSNGR_TYPE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'BUS_USE_CL_CD') }} AS BUS_USE_CL_CD,
        GVW_NO,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRUCK_RADIUS_CL_CD') }} AS TRUCK_RADIUS_CL_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRUCK_SEC_CL_CD') }} AS TRUCK_SEC_CL_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SEC_CL_CD') }} AS SEC_CL_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SIZE_CL_CD') }} AS SIZE_CL_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRLR_HOW_USED_CD') }} AS TRLR_HOW_USED_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'FAR_TERM_ZONE') }} AS FAR_TERM_ZONE,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'GARAGING_ZONE') }} AS GARAGING_ZONE,
        DAYS_SCHL_YR_CNT,
        (
            CASE
                WHEN UPPER(TRIM(CAST(SCHL_BUS_PRORATION_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(SCHL_BUS_PRORATION_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS SCHL_BUS_PRORATION_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SEATING_CPCTY_CD') }} AS SEATING_CPCTY_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PUB_TRNSP_TYPE_CD') }} AS PUB_TRNSP_TYPE_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PUB_TRNSP_RADIUS_CL_CD') }} AS PUB_TRNSP_RADIUS_CL_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SPCL_VEH_CL_CD') }} AS SPCL_VEH_CL_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'ENGINE_SIZE_CD') }} AS ENGINE_SIZE_CD,
        GROSS_RECEIPTS_AMT,
        (
            CASE
                WHEN UPPER(TRIM(CAST(NON_OWNED_AUTOS_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(NON_OWNED_AUTOS_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS NON_OWNED_AUTOS_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'DAYS_VEH_LEASED_CNT') }} AS DAYS_VEH_LEASED_CNT,
        FCTRY_TST_EMP_CNT,
        REPO_AUTOS_CNT,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PHYS_DMG_CLASS_CD') }} AS PHYS_DMG_CLASS_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SUPP_TYPE_CD') }} AS SUPP_TYPE_CD,
        COST_HIRE_FOR_COLL_AMT,
        COST_HIRE_FOR_LIAB_AMT,
        COST_HIRE_FOR_EXCS_LIAB_AMT,
        COST_HIRE_FOR_OTC_AMT,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SPCL_VEH_TYPE_CD') }} AS SPCL_VEH_TYPE_CD,
        (
            CASE
                WHEN UPPER(TRIM(CAST(REG_USE_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(REG_USE_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS REG_USE_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'CURR_CD') }} AS CURR_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'ZIP_CD') }} AS ZIP_CD,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'ZIP_CD_OVERRIDE') }} AS ZIP_CD_OVERRIDE,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'TERR') }} AS TERR,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'GARAGE_LOC') }} AS GARAGE_LOC,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRNSP_PCT_TEXT') }} AS TRNSP_PCT_TEXT,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'SAFETY_SCORE') }} AS SAFETY_SCORE,
        (
            CASE
                WHEN UPPER(TRIM(CAST(SAFETY_SCORE_DISC_APPLIES_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(SAFETY_SCORE_DISC_APPLIES_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS SAFETY_SCORE_DISC_APPLIES_FL,
        (
            CASE
                WHEN UPPER(TRIM(CAST(TELEMATICS_DISC_APPLIES_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(TELEMATICS_DISC_APPLIES_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS TELEMATICS_DISC_APPLIES_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'USED_AS_TNC_OR_ON_DEMAND_CD') }} AS USED_AS_TNC_OR_ON_DEMAND_CD,
        (
            CASE
                WHEN UPPER(TRIM(CAST(MECHANICAL_LIFT_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(MECHANICAL_LIFT_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS MECHANICAL_LIFT_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'PUB_TRNSP_GRP_CD') }} AS PUB_TRNSP_GRP_CD,
        (
            CASE
                WHEN UPPER(TRIM(CAST(TRNSP_PUB_PSNGR_FOR_COMP_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(TRNSP_PUB_PSNGR_FOR_COMP_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS TRNSP_PUB_PSNGR_FOR_COMP_FL,
        (
            CASE
                WHEN UPPER(TRIM(CAST(AUTO_RENTED_TO_OTHR_CARR_FL AS VARCHAR))) IN ('TRUE','T','YES','Y','1') THEN 'Y'
                WHEN UPPER(TRIM(CAST(AUTO_RENTED_TO_OTHR_CARR_FL AS VARCHAR))) IN ('FALSE','F','NO','N','0') THEN 'N'
                ELSE 'U'
            END
        ) AS AUTO_RENTED_TO_OTHR_CARR_FL,
        {{ m_cleanse('VARCHAR_SINGLESPACE', 'VEH_INDC_CD') }} AS VEH_INDC_CD
    FROM INT_CA_VEH_PUBTRNSP
)

/*==========================================================
  SCD Configuration
==========================================================*/

{%- set key_cols = [
    'CA_CVRBL_KEY',
    'ROW_PROC_DTS',
    'END_EFF_DT'
] -%}

{%- set scd2_cols = [
    'END_EXP_DT',
    'SOURCE_SYSTEM',
    'CVRBL_TYPE_CD',
    'VEH_ID_NO',
    'MAKE_NAME',
    'MODEL_NAME',
    'MODEL_YR',
    'VEH_NO',
    'ORIG_COST_NEW_AMT',
    'STATED_AMT',
    'UNIT_NO',
    'LIC_JURS_CD',
    'LIC_PLATE',
    'LEASE_OR_RENT_FL',
    'LEN_OF_LEASE_CD',
    'CL_CD',
    'FLEET_FL',
    'LESSOR_AN_EMP_FL',
    'PRVT_PSNGR_OPER_EXPER_CD',
    'PRVT_PSNGR_USE_CD',
    'PRVT_PSNGR_TYPE_CD',
    'BUS_USE_CL_CD',
    'GVW_NO',
    'TRUCK_RADIUS_CL_CD',
    'TRUCK_SEC_CL_CD',
    'SEC_CL_CD',
    'SIZE_CL_CD',
    'TRLR_HOW_USED_CD',
    'FAR_TERM_ZONE',
    'GARAGING_ZONE',
    'DAYS_SCHL_YR_CNT',
    'SCHL_BUS_PRORATION_FL',
    'SEATING_CPCTY_CD',
    'PUB_TRNSP_TYPE_CD',
    'PUB_TRNSP_RADIUS_CL_CD',
    'SPCL_VEH_CL_CD',
    'ENGINE_SIZE_CD',
    'GROSS_RECEIPTS_AMT',
    'NON_OWNED_AUTOS_FL',
    'DAYS_VEH_LEASED_CNT',
    'FCTRY_TST_EMP_CNT',
    'REPO_AUTOS_CNT',
    'PHYS_DMG_CLASS_CD',
    'SUPP_TYPE_CD',
    'COST_HIRE_FOR_COLL_AMT',
    'COST_HIRE_FOR_LIAB_AMT',
    'COST_HIRE_FOR_EXCS_LIAB_AMT',
    'COST_HIRE_FOR_OTC_AMT',
    'SPCL_VEH_TYPE_CD',
    'REG_USE_FL',
    'CURR_CD',
    'ZIP_CD',
    'ZIP_CD_OVERRIDE',
    'TERR',
    'GARAGE_LOC',
    'TRNSP_PCT_TEXT',
    'SAFETY_SCORE',
    'SAFETY_SCORE_DISC_APPLIES_FL',
    'TELEMATICS_DISC_APPLIES_FL',
    'USED_AS_TNC_OR_ON_DEMAND_CD',
    'MECHANICAL_LIFT_FL',
    'PUB_TRNSP_GRP_CD',
    'TRNSP_PUB_PSNGR_FOR_COMP_FL',
    'AUTO_RENTED_TO_OTHR_CARR_FL',
    'VEH_INDC_CD'
] -%}

{%- set scd1_cols = [
    'POL_KEY',
    'POL_LINE_KEY',
    'OWNING_CVRBL_KEY',
    'CVRBL_TYPE_KEY',
    'GARAGE_LOC_KEY'
] -%}

{{ m_scd2_scd1(
    'INT_CA_VEH_PUBTRNSP_cleaned',
    key_cols,
    scd2_cols,
    scd1_cols
) }}