
{{ config(
    materialized='table'
) }}

/*==========================================================
  Source CTEs
==========================================================*/

WITH pcx_ca7transaction AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7transaction') }}
),

pcx_ca7cost AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7cost') }}
),

pc_policyperiod AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_policyperiod') }}
),

pc_producercode AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_producercode') }}
),

pc_organization AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_organization') }}
),

pc_job AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_job') }}
),

pc_auditinformation AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_auditinformation') }}
),

pc_policyfxrate AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_policyfxrate') }}
),

pc_exchangerateset AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_exchangerateset') }}
),

pc_exchangerate AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_exchangerate') }}
),

pc_paymentplansummary AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_paymentplansummary') }}
),

pcx_ca7jurisdictioncov AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7jurisdictioncov') }}
),

pcx_ca7vehiclecov AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7vehiclecov') }}
),

pcx_ca7linecov AS (
    SELECT *
    FROM {{ source('sources_ca', 'pcx_ca7linecov') }}
),

pctl_policyperiodstatus AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_policyperiodstatus') }}
),

pctl_currency AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_currency') }}
),

pctl_chargepattern AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_chargepattern') }}
),

pctl_job AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_job') }}
),

pctl_paymenttype AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_paymenttype') }}
),

pctl_auditscheduletype AS (
    SELECT *
    FROM {{ source('sources_common', 'pctl_auditscheduletype') }}
),

pctl_ca7cost AS (
    SELECT *
    FROM {{ source('sources_ca', 'pctl_ca7cost') }}
),

pc_systemparameter AS (
    SELECT *
    FROM {{ source('sources_common', 'pc_systemparameter') }}
),

etl_control_parm AS (
    SELECT
        MAX(start_extract_date) AS start_extract_date,
        MAX(end_extract_date)   AS end_extract_date
    FROM {{ ref('etl_control_parm') }}
),

/*==========================================================
  Reporting Currency
==========================================================*/

rpt_curr AS (
    SELECT ID
    FROM pctl_currency
    WHERE TYPECODE = (
        SELECT VALUE
        FROM pc_systemparameter
        WHERE Name = 'config_param_DefaultApplicationCurrency'
    )
),

/*==========================================================
  Business Mapping
==========================================================*/

INT_CAPREMTXN AS (

SELECT

    ----------------------------------------------------------
    -- Business Keys
    ----------------------------------------------------------

    'GWPC'
        || '-'
        || 'CA'
        || '-'
        || src.PublicID
        AS CA_PREM_TRANS_KEY,

    'GWPC'
        || '-'
        || org.PublicID
        AS AGCY_KEY,

    'GWPC'
        || '-'
        || prodcode.PublicID
        AS AGNT_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        AS POL_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || CAST(cost.CommAutoLine AS VARCHAR)
        AS POL_LINE_KEY,

    CASE
        WHEN cost.CA7Vehicle IS NOT NULL
            THEN 'GWPC'
                || '-'
                || CAST(polper.PeriodID AS VARCHAR)
                || '-'
                || 'Vehicle'
                || '-'
                || CAST(cost.CA7Vehicle AS VARCHAR)
        WHEN cost.CA7Jurisdiction IS NOT NULL
            THEN 'GWPC'
                || '-'
                || CAST(polper.PeriodID AS VARCHAR)
                || '-'
                || 'Jurisdiction'
                || '-'
                || CAST(cost.CA7Jurisdiction AS VARCHAR)
        ELSE NULL
    END AS CA_CVRBL_KEY,

    CASE
        WHEN COALESCE(
            CA7JurisdictionCov.PatternCode,
            CA7VehicleCov.PatternCode,
            CA7LineCov.PatternCode
        ) IS NULL THEN NULL
        ELSE 'GWPC'
            || '-'
            || COALESCE(
                CA7JurisdictionCov.PatternCode,
                CA7VehicleCov.PatternCode,
                CA7LineCov.PatternCode
            )
    END AS COVG_KEY,

    NULL AS COND_KEY,

    NULL AS EXCL_KEY,

    CASE
        WHEN cost.CA7JurisdictionCov IS NOT NULL
            THEN 'GWPC'
                || '-'
                || CAST(polper.PeriodID AS VARCHAR)
                || '-'
                || 'CA7JurisdictionCov'
                || '-'
                || CAST(cost.CA7JurisdictionCov AS VARCHAR)
        WHEN cost.CA7VehicleCov IS NOT NULL
            THEN 'GWPC'
                || '-'
                || CAST(polper.PeriodID AS VARCHAR)
                || '-'
                || 'CA7VehicleCov'
                || '-'
                || CAST(cost.CA7VehicleCov AS VARCHAR)
        WHEN cost.CA7LineCov IS NOT NULL
            THEN 'GWPC'
                || '-'
                || CAST(polper.PeriodID AS VARCHAR)
                || '-'
                || 'CA7LineCov'
                || '-'
                || CAST(cost.CA7LineCov AS VARCHAR)
        ELSE NULL
    END AS CA_COVG_KEY,

    NULL AS CA_COND_KEY,

    NULL AS CA_EXCL_KEY,

    'D' AS REC_TYPE_KEY,

    'GWPC'
        || '-'
        || CAST(polper.PeriodID AS VARCHAR)
        || '-'
        || CAST(cost.AdditionalInsured AS VARCHAR)
        AS ADDL_INS_KEY,

    'GWPC' AS SOURCE_SYSTEM,

    ----------------------------------------------------------
    -- Transaction Attributes
    ----------------------------------------------------------

    CAST(TO_CHAR(src.WrittenDate, 'YYYYMM') AS INT)
        AS ACCTG_PRD_ID,

    job.CloseDate AS TRANS_PROC_DTS,

    job_orig.CloseDate AS ORIG_TRANS_PROC_DTS,

    CAST(polper_orig.EditEffectiveDate AS DATE)
        AS ORIG_END_EFF_DT,

    CAST(polper_orig.EditEffectiveDate AS DATE)
        AS ORIG_EDIT_EFF_DT,

    CAST(src.EffDate AS DATE) AS TRANS_EFF_DT,

    CAST(src.ExpDate AS DATE) AS TRANS_EXP_DT,

    jtype.TYPECODE AS TRANS_CD,

    costtype.TYPECODE AS TRANS_TYPE_CD,

    src.ID AS TRANS_SEQ,

    CASE
        WHEN cost.CA7Vehicle IS NOT NULL THEN 'Vehicle'
        WHEN cost.CA7Jurisdiction IS NOT NULL THEN 'Jurisdiction'
        ELSE NULL
    END AS CVRBL_TYPE_CD,

    ----------------------------------------------------------
    -- Premium Amounts (Transaction Currency)
    ----------------------------------------------------------

    cost.Basis AS PREM_BASIS_AMT,

    cost.StandardBaseRate AS STD_BASE_RATE,

    cost.StandardAdjRate AS STD_ADJ_RATE,

    cost.StandardAmount AS STD_AMT,

    cost.StandardTermAmount AS STD_TERM_AMT,

    cost.OverrideBaseRate AS OVERRIDE_BASE_RATE,

    cost.OverrideAdjRate AS OVERRIDE_ADJ_RATE,

    cost.OverrideAmount AS OVERRIDE_AMT,

    cost.OverrideTermAmount AS OVERRIDE_TERM_AMT,

    cost.ActualBaseRate AS ACT_BASE_RATE,

    cost.ActualAdjRate AS ACT_ADJ_RATE,

    cost.ActualAmount AS ACT_AMT,

    cost.ActualTermAmount AS ACT_TERM_AMT,

    curr.TYPECODE AS CURR_CD,

    src.Amount AS TRANS_AMT,

    CASE jtype.TYPECODE
        WHEN 'Submission' THEN 'NEW'
        WHEN 'Issuance' THEN 'NEW'
        WHEN 'Renewal' THEN 'RENEW'
        WHEN 'PolicyChange' THEN 'ENDORSE'
        WHEN 'Cancellation' THEN 'CANCEL'
        WHEN 'Reinstatement' THEN 'REINSTATE'
        WHEN 'Audit' THEN 'AUDIT'
        WHEN 'Rewrite' THEN 'REINSTATE'
        WHEN 'RewriteNewAccount' THEN 'REINSTATE'
        WHEN 'Job' THEN 'UNKNOWN'
    END AS TRANS_ALLOC_CD,

    ----------------------------------------------------------
    -- Settlement Currency Amounts
    ----------------------------------------------------------

    NULL AS STTLMNT_PREM_BASIS_AMT,

    cost.StandardAmountBilling AS STTLMNT_STD_AMT,

    cost.StandardTermAmountBilling AS STTLMNT_STD_TERM_AMT,

    cost.OverrideAmountBilling AS STTLMNT_OVERRIDE_AMT,

    cost.OverrideTermAmountBilling AS STTLMNT_OVERRIDE_TERM_AMT,

    cost.ActualAmountBilling AS STTLMNT_ACT_AMT,

    cost.ActualTermAmountBilling AS STTLMNT_ACT_TERM_AMT,

    currbill.TYPECODE AS STTLMNT_CURR_CD,

    src.AmountBilling AS STTLMNT_TRANS_AMT,

    CASE
        WHEN src.Amount_cur = src.AmountBilling_cur THEN 1.0000000
        ELSE polfx.Rate
    END AS TRANS_TO_STTLMNT_RATE,

    ----------------------------------------------------------
    -- Regulatory Reporting Currency (NULL for CA)
    ----------------------------------------------------------

    NULL AS REG_RPT_PREM_BASIS_AMT,

    NULL AS REG_RPT_STD_AMT,

    NULL AS REG_RPT_STD_TERM_AMT,

    NULL AS REG_RPT_OVERRIDE_AMT,

    NULL AS REG_RPT_OVERRIDE_TERM_AMT,

    NULL AS REG_RPT_ACT_AMT,

    NULL AS REG_RPT_ACT_TERM_AMT,

    NULL AS REG_RPT_CURR_CD,

    NULL AS REG_RPT_TRANS_AMT,

    NULL AS TRANS_TO_REG_RPT_RATE,

    ----------------------------------------------------------
    -- Reporting Currency Amounts
    ----------------------------------------------------------

    NULL AS RPT_PREM_BASIS_AMT,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN cost.StandardAmount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN cost.StandardAmountBilling
        ELSE CAST(ROUND(cost.StandardAmount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_STD_AMT,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN cost.StandardTermAmount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN cost.StandardTermAmountBilling
        ELSE CAST(ROUND(cost.StandardTermAmount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_STD_TERM_AMT,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN cost.OverrideAmount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN cost.OverrideAmountBilling
        ELSE CAST(ROUND(cost.OverrideAmount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_OVERRIDE_AMT,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN cost.OverrideTermAmount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN cost.OverrideTermAmountBilling
        ELSE CAST(ROUND(cost.OverrideTermAmount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_OVERRIDE_TERM_AMT,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN cost.ActualAmount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN cost.ActualAmountBilling
        ELSE CAST(ROUND(cost.ActualAmount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_ACT_AMT,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN cost.ActualTermAmount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN cost.ActualTermAmountBilling
        ELSE CAST(ROUND(cost.ActualTermAmount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_ACT_TERM_AMT,

    curr_rpt.TYPECODE AS RPT_CURR_CD,

    CASE
        WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
        WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
        ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
    END AS RPT_TRANS_AMT,

    CASE
        WHEN src.Amount_cur = rpt_curr.ID THEN 1.0000000
        ELSE CAST(xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale) AS NUMERIC(15,10))
    END AS TRANS_TO_RPT_RATE,

    ----------------------------------------------------------
    -- Derived Premium Buckets
    ----------------------------------------------------------

    CASE
        WHEN charge.TYPECODE = 'Premium' AND src.Charged = '1' THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS WRITTEN_PREM_AMT,

    CASE
        WHEN charge.TYPECODE = 'Premium' AND src.Written = '1' AND audittype.TYPECODE IS NULL THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS INFORCE_PREM_AMT,

    CASE
        WHEN charge.TYPECODE = 'Taxes' THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS TAX_AMT,

    CASE
        WHEN charge.TYPECODE IN ('InstallmentFee', 'ReinstatementFee') THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS FEE_AMT,

    CASE
        WHEN charge.TYPECODE = 'Surcharges' THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS SRCHG_AMT,

    0 AS COMM_AMT,

    0 AS COMM_PCT,

    CASE
        WHEN charge.TYPECODE = 'Premium' AND src.Written = '1'
            AND (
                (src.Charged = '0' AND audittype.TYPECODE IS NULL)
                OR (cost.SubjectToReporting = '1' AND src.Charged = '1' AND pmttype.TYPECODE <> 'Installment')
            ) THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS EST_PREM_AMT,

    CASE
        WHEN charge.TYPECODE = 'Premium' AND src.Charged = '1' AND audittype.TYPECODE = 'PremiumReport' THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS RPT_PREM_AMT,

    CASE
        WHEN charge.TYPECODE = 'Premium' AND src.Charged = '1' AND audittype_orig.TYPECODE = 'FinalAudit' THEN
            CASE
                WHEN rpt_curr.ID = src.Amount_cur THEN src.Amount
                WHEN rpt_curr.ID = src.AmountBilling_cur THEN src.AmountBilling
                ELSE CAST(ROUND(src.Amount * xr.NormalizedRate * POWER(CAST(10 AS DECIMAL(18,6)), (-1) * xr.RateScale), 2) AS NUMERIC(18,2))
            END
        ELSE 0
    END AS AUDIT_PREM_AMT,

    CASE
        WHEN charge.TYPECODE = 'Premium' AND src.Written = '1'
            AND (
                (src.Charged = '0' AND audittype.TYPECODE IS NULL)
                OR (cost.SubjectToReporting = '1' AND src.Charged = '1' AND pmttype.TYPECODE <> 'Installment')
            ) THEN 'Y'
        ELSE 'N'
    END AS AUDITABLE_FL,

    CASE
        WHEN src.Written = '1' AND src.ToBeAccrued = '0' THEN 'Y'
        ELSE 'N'
    END AS PREM_FULLY_EARNED_FL

FROM pcx_ca7transaction src

INNER JOIN pcx_ca7cost cost
    ON cost.ID = src.CA7Cost

INNER JOIN pc_policyperiod polper
    ON polper.ID = src.BranchID

INNER JOIN pc_policyperiod polper_orig
    ON polper_orig.ID = cost.BranchID

INNER JOIN pc_producercode prodcode
    ON prodcode.ID = polper_orig.ProducerCodeOfRecordID

INNER JOIN pc_organization org
    ON org.ID = prodcode.OrganizationID

INNER JOIN pc_job job
    ON job.ID = polper.JobID

INNER JOIN pc_job job_orig
    ON job_orig.ID = polper_orig.JobID

LEFT JOIN pc_auditinformation auditinfo
    ON auditinfo.ID = job.AuditInformationID

LEFT JOIN pc_auditinformation auditinfo_orig
    ON auditinfo_orig.ID = job_orig.AuditInformationID

LEFT JOIN pc_policyfxrate polfx
    ON polfx.ID = src.PolicyFXRate

CROSS JOIN rpt_curr

LEFT JOIN pc_exchangerateset xr_set
    ON src.WrittenDate BETWEEN xr_set.EffectiveDate
        AND COALESCE(xr_set.ExpireDate, '9999-01-01')

LEFT JOIN pc_exchangerate xr
    ON xr.ExchangeRateSetID = xr_set.ID
    AND xr.BaseCurrency = src.Amount_cur
    AND xr.PriceCurrency = rpt_curr.ID

LEFT JOIN pctl_chargepattern charge
    ON charge.ID = cost.ChargePattern

LEFT JOIN pctl_job jtype
    ON jtype.ID = job.Subtype

INNER JOIN pctl_policyperiodstatus status
    ON status.ID = polper.Status

INNER JOIN pctl_currency curr
    ON curr.ID = src.Amount_cur

LEFT JOIN pc_paymentplansummary pmtplansum
    ON pmtplansum.PolicyPeriod = polper.ID
    AND pmtplansum.Retired = 0

LEFT JOIN pctl_paymenttype pmttype
    ON pmttype.ID = pmtplansum.PaymentPlanType

LEFT JOIN pctl_auditscheduletype audittype
    ON audittype.ID = auditinfo.AuditScheduleType

LEFT JOIN pctl_auditscheduletype audittype_orig
    ON audittype_orig.ID = auditinfo_orig.AuditScheduleType

INNER JOIN pctl_currency curr_rpt
    ON curr_rpt.ID = rpt_curr.ID

LEFT JOIN pctl_currency currbill
    ON currbill.ID = src.AmountBilling_cur

INNER JOIN pctl_ca7cost costtype
    ON costtype.ID = cost.Subtype

LEFT JOIN pcx_ca7jurisdictioncov CA7JurisdictionCov
    ON CA7JurisdictionCov.FixedID = cost.CA7JurisdictionCov
    AND CA7JurisdictionCov.BranchID = cost.BranchID
    AND COALESCE(cost.EffectiveDate, polper_orig.PeriodStart)
        >= COALESCE(CA7JurisdictionCov.EffectiveDate, polper_orig.PeriodStart)
    AND COALESCE(cost.EffectiveDate, polper_orig.PeriodStart)
        < COALESCE(CA7JurisdictionCov.ExpirationDate, polper_orig.PeriodEnd)

LEFT JOIN pcx_ca7vehiclecov CA7VehicleCov
    ON CA7VehicleCov.FixedID = cost.CA7VehicleCov
    AND CA7VehicleCov.BranchID = cost.BranchID
    AND COALESCE(cost.EffectiveDate, polper_orig.PeriodStart)
        >= COALESCE(CA7VehicleCov.EffectiveDate, polper_orig.PeriodStart)
    AND COALESCE(cost.EffectiveDate, polper_orig.PeriodStart)
        < COALESCE(CA7VehicleCov.ExpirationDate, polper_orig.PeriodEnd)

LEFT JOIN pcx_ca7linecov CA7LineCov
    ON CA7LineCov.FixedID = cost.CA7LineCov
    AND CA7LineCov.BranchID = cost.BranchID
    AND COALESCE(cost.EffectiveDate, polper_orig.PeriodStart)
        >= COALESCE(CA7LineCov.EffectiveDate, polper_orig.PeriodStart)
    AND COALESCE(cost.EffectiveDate, polper_orig.PeriodStart)
        < COALESCE(CA7LineCov.ExpirationDate, polper_orig.PeriodEnd)

CROSS JOIN etl_control_parm ecp

WHERE
    status.TYPECODE IN ('Bound', 'AuditComplete')

    AND job.CloseDate <= ecp.end_extract_date

    {% if is_incremental() %}
    AND job.CloseDate > ecp.start_extract_date
    {% endif %}

),

/*==========================================================
  Cleansing
==========================================================*/

INT_CAPREMTXN_cleaned AS (

SELECT
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_PREM_TRANS_KEY') }})         AS CA_PREM_TRANS_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'AGCY_KEY') }})                  AS AGCY_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'AGNT_KEY') }})                  AS AGNT_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_KEY') }})                   AS POL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'POL_LINE_KEY') }})              AS POL_LINE_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_CVRBL_KEY') }})              AS CA_CVRBL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'COVG_KEY') }})                  AS COVG_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'COND_KEY') }}                   AS COND_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'EXCL_KEY') }}                   AS EXCL_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'CA_COVG_KEY') }})               AS CA_COVG_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CA_COND_KEY') }}                AS CA_COND_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CA_EXCL_KEY') }}                AS CA_EXCL_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'REC_TYPE_KEY') }}               AS REC_TYPE_KEY,
    UPPER({{ m_cleanse('VARCHAR_NOKEY', 'ADDL_INS_KEY') }})              AS ADDL_INS_KEY,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'SOURCE_SYSTEM') }}              AS SOURCE_SYSTEM,
    {{ m_cleanse('INTEGER_ZERO', 'ACCTG_PRD_ID') }}                      AS ACCTG_PRD_ID,
    {{ m_cleanse('TIMESTAMP', 'TRANS_PROC_DTS') }}                       AS TRANS_PROC_DTS,
    {{ m_cleanse('TIMESTAMP', 'ORIG_TRANS_PROC_DTS') }}                  AS ORIG_TRANS_PROC_DTS,
    {{ m_cleanse('DATE_LOW', 'ORIG_END_EFF_DT') }}                       AS ORIG_END_EFF_DT,
    {{ m_cleanse('DATE_LOW', 'ORIG_EDIT_EFF_DT') }}                      AS ORIG_EDIT_EFF_DT,
    {{ m_cleanse('DATE_LOW', 'TRANS_EFF_DT') }}                          AS TRANS_EFF_DT,
    {{ m_cleanse('DATE_HIGH', 'TRANS_EXP_DT') }}                         AS TRANS_EXP_DT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRANS_CD') }}                   AS TRANS_CD,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRANS_TYPE_CD') }}              AS TRANS_TYPE_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'TRANS_SEQ') }}                         AS TRANS_SEQ,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CVRBL_TYPE_CD') }}              AS CVRBL_TYPE_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'PREM_BASIS_AMT') }}                    AS PREM_BASIS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STD_BASE_RATE') }}                     AS STD_BASE_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'STD_ADJ_RATE') }}                      AS STD_ADJ_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'STD_AMT') }}                           AS STD_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STD_TERM_AMT') }}                      AS STD_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'OVERRIDE_BASE_RATE') }}                AS OVERRIDE_BASE_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'OVERRIDE_ADJ_RATE') }}                 AS OVERRIDE_ADJ_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'OVERRIDE_AMT') }}                      AS OVERRIDE_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'OVERRIDE_TERM_AMT') }}                 AS OVERRIDE_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'ACT_BASE_RATE') }}                     AS ACT_BASE_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'ACT_ADJ_RATE') }}                      AS ACT_ADJ_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'ACT_AMT') }}                           AS ACT_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'ACT_TERM_AMT') }}                      AS ACT_TERM_AMT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'CURR_CD') }}                    AS CURR_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'TRANS_AMT') }}                         AS TRANS_AMT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'TRANS_ALLOC_CD') }}             AS TRANS_ALLOC_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_PREM_BASIS_AMT') }}           AS STTLMNT_PREM_BASIS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_STD_AMT') }}                  AS STTLMNT_STD_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_STD_TERM_AMT') }}             AS STTLMNT_STD_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_OVERRIDE_AMT') }}             AS STTLMNT_OVERRIDE_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_OVERRIDE_TERM_AMT') }}        AS STTLMNT_OVERRIDE_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_ACT_AMT') }}                  AS STTLMNT_ACT_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_ACT_TERM_AMT') }}             AS STTLMNT_ACT_TERM_AMT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'STTLMNT_CURR_CD') }}           AS STTLMNT_CURR_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'STTLMNT_TRANS_AMT') }}                AS STTLMNT_TRANS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'TRANS_TO_STTLMNT_RATE') }}            AS TRANS_TO_STTLMNT_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_PREM_BASIS_AMT') }}           AS REG_RPT_PREM_BASIS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_STD_AMT') }}                  AS REG_RPT_STD_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_STD_TERM_AMT') }}             AS REG_RPT_STD_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_OVERRIDE_AMT') }}             AS REG_RPT_OVERRIDE_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_OVERRIDE_TERM_AMT') }}        AS REG_RPT_OVERRIDE_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_ACT_AMT') }}                  AS REG_RPT_ACT_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_ACT_TERM_AMT') }}             AS REG_RPT_ACT_TERM_AMT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'REG_RPT_CURR_CD') }}           AS REG_RPT_CURR_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'REG_RPT_TRANS_AMT') }}                AS REG_RPT_TRANS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'TRANS_TO_REG_RPT_RATE') }}            AS TRANS_TO_REG_RPT_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_PREM_BASIS_AMT') }}               AS RPT_PREM_BASIS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_STD_AMT') }}                      AS RPT_STD_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_STD_TERM_AMT') }}                 AS RPT_STD_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_OVERRIDE_AMT') }}                 AS RPT_OVERRIDE_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_OVERRIDE_TERM_AMT') }}            AS RPT_OVERRIDE_TERM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_ACT_AMT') }}                      AS RPT_ACT_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_ACT_TERM_AMT') }}                 AS RPT_ACT_TERM_AMT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'RPT_CURR_CD') }}               AS RPT_CURR_CD,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_TRANS_AMT') }}                    AS RPT_TRANS_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'TRANS_TO_RPT_RATE') }}                AS TRANS_TO_RPT_RATE,
    {{ m_cleanse('NUMERIC_ZERO', 'WRITTEN_PREM_AMT') }}                 AS WRITTEN_PREM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'INFORCE_PREM_AMT') }}                 AS INFORCE_PREM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'TAX_AMT') }}                          AS TAX_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'FEE_AMT') }}                          AS FEE_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'SRCHG_AMT') }}                        AS SRCHG_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'COMM_AMT') }}                         AS COMM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'COMM_PCT') }}                         AS COMM_PCT,
    {{ m_cleanse('NUMERIC_ZERO', 'EST_PREM_AMT') }}                     AS EST_PREM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'RPT_PREM_AMT') }}                     AS RPT_PREM_AMT,
    {{ m_cleanse('NUMERIC_ZERO', 'AUDIT_PREM_AMT') }}                   AS AUDIT_PREM_AMT,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'AUDITABLE_FL') }}              AS AUDITABLE_FL,
    {{ m_cleanse('VARCHAR_SINGLESPACE', 'PREM_FULLY_EARNED_FL') }}      AS PREM_FULLY_EARNED_FL
FROM INT_CAPREMTXN

)

/*==========================================================
  Final Select
==========================================================*/

SELECT *
FROM INT_CAPREMTXN_cleaned
