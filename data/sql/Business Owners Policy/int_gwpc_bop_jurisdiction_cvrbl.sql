

with etl_control_parm as (

    select
        upper(model_name) as model_name,
        upper(source_system) as source_system,
        upper(load_type) as load_type,
        cast(start_extract_date as timestamp) as start_extract_date,
        cast(end_extract_date as timestamp) as end_extract_date
    from "policy_center"."main"."etl_control_parm"
    where upper(model_name) = 'BP_CVRBL'
        and upper(source_system) = 'GWPC'
        and upper(active_fl) = 'Y'
    qualify row_number() over (
        order by cast(start_extract_date as timestamp) desc
    ) = 1

),

bp7_jurisdiction_latest as (

    select
        pccp7.branchid,
        pccp7.fixedid,
        pccp7.effectivedate,
        pccp7.expirationdate,
        pccp7.id
    from (
        select
            poll.branchid,
            poll.fixedid,
            poll.effectivedate,
            poll.expirationdate,
            poll.id,
            row_number() over (
                partition by poll.branchid, poll.fixedid
                order by poll.expirationdate desc
            ) as rn
        from "policy_center"."main"."pcx_bp7jurisdiction" as poll
        inner join "policy_center"."main"."pc_policyperiod" as polper
            on polper.id = poll.branchid
    ) as pccp7
    where pccp7.rn = 1

),

int_gwpc_bop_jurisdiction_cvrbl as (

    select
        coalesce(nullif(ltrim(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || 'BP7JURISDICTION' || '-' || cast(src.fixedid as varchar(1000)) as varchar)), ''), '?') as bp_cvrbl_key,
        coalesce(nullif(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) as varchar), ''), 'NOKEY') as pol_key,
        coalesce(nullif(cast(case when src.bp7businessownersline is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || cast(src.bp7businessownersline as varchar(1000)) else null end as varchar), ''), 'NOKEY') as pol_line_key,
        coalesce(nullif(cast('GWPC' || '-' || 'BP7JURISDICTION' as varchar), ''), 'NOKEY') as cvrbl_type_key,
        cast(coalesce(src.effectivedate, polper.periodstart) as date) as end_eff_dt,
        cast(coalesce(src.expirationdate, polper.periodend) as date) as end_exp_dt,
        coalesce(nullif(ltrim(cast('GWPC' as varchar)), ''), '?') as source_system,
        coalesce(nullif(ltrim(cast('BP7JURISDICTION' as varchar)), ''), ' ') as cvrbl_type_cd,
        coalesce(nullif(ltrim(cast(preferredcoveragecurrency.typecode as varchar)), ''), ' ') as prefd_covg_curr_cd,
        
        cast(coalesce(src.effectivedate, polper.periodstart) as timestamp) as etl_end_eff_dts,
        cast(coalesce(src.expirationdate, polper.periodend) as timestamp) as etl_end_exp_dts,
        to_json(struct_pack(
            JS_STATE_CD := coalesce(nullif(ltrim(cast(state.typecode as varchar)), ''), ' '),
            JS_LIQUOR_LIAB_GRADE := coalesce(nullif(ltrim(cast(src.bp7liquorliabgrade as varchar)), ''), ' '),
            JS_LIQUOR_LIAB_GRADE_OFF_PREMISE := coalesce(nullif(ltrim(cast(src.bp7liquorliabgradeoffpremise as varchar)), ''), ' '),
            JS_LIQUOR_LIAB_GRADE_ON_PREMISE := coalesce(nullif(ltrim(cast(src.bp7liquorliabgradeonpremise as varchar)), ''), ' '),
            JS_LIAB_CO_TIER_EXT := coalesce(nullif(ltrim(cast(src.liabcompanytier_ext as varchar)), ''), ' '),
            JS_LIAB_TIER_FCTR_EXT := coalesce(src.liabtierfactor_ext, 0),
            JS_MI_LIQUOR_COMPLIANCE_EXT := coalesce(nullif(ltrim(cast(src.bp7miliqcomp as varchar)), ''), ' '),
            JS_PREFD_COVG_CURR_CD := coalesce(nullif(ltrim(cast(preferredcoveragecurrency.typecode as varchar)), ''), ' '),
            JS_PREFD_STTLMNT_CURR_CD := coalesce(nullif(ltrim(cast(preferredsettlementcurrency.typecode as varchar)), ''), ' '),
            JS_PRICING_MODEL_ORDER_DT_EXT_DTS := strftime(src.pricingmodelorderdate_ext, '%Y-%m-%d %H:%M:%S'),
            JS_PRICING_MODEL_ORDER_STATUS_EXT_CD := coalesce(nullif(ltrim(cast(pricingmodelorderstatus_ext.typecode as varchar)), ''), ' '),
            JS_PROP_CO_TIER_EXT := coalesce(nullif(ltrim(cast(src.propcompanytier_ext as varchar)), ''), ' '),
            JS_PROP_TIER_FCTR_EXT := coalesce(src.proptierfactor_ext, 0),
            JS_USER_UPDATED_COVG_CURR_FL := coalesce(
        case
            when cast(src.userupdatedcoveragecurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedcoveragecurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            JS_USER_UPDATED_STTLMNT_CURR_FL := coalesce(
        case
            when cast(src.userupdatedsettlementcurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedsettlementcurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    )
        )) as coverable_items,
        
        job.closedate as etl_row_eff_dts
    from "policy_center"."main"."pcx_bp7jurisdiction" as src
    inner join "policy_center"."main"."pc_policyperiod" as polper
        on polper.id = src.branchid
    inner join "policy_center"."main"."pc_job" as job
        on job.id = polper.jobid
    cross join etl_control_parm as etl_ctl
    inner join "policy_center"."main"."pctl_policyperiodstatus" as status
        on status.id = polper.status
    left join "policy_center"."main"."pctl_currency" as preferredsettlementcurrency
        on preferredsettlementcurrency.id = src.preferredsettlementcurrency
    inner join "policy_center"."main"."pctl_currency" as preferredcoveragecurrency
        on preferredcoveragecurrency.id = src.preferredcoveragecurrency
    left join "policy_center"."main"."pctl_pricingmodelorderstatus_ext" as pricingmodelorderstatus_ext
        on pricingmodelorderstatus_ext.id = src.pricingmodelorderstatus_ext
    left join "policy_center"."main"."pctl_jurisdiction" as state
        on state.id = src.state
    left join bp7_jurisdiction_latest as srcx
        on srcx.branchid = src.branchid
        and srcx.fixedid = src.fixedid
        and srcx.id = src.id
    where status.typecode = 'Bound'
        and (
            etl_ctl.load_type = 'INITIAL'
            or cast(job.closedate as timestamp) between etl_ctl.start_extract_date and etl_ctl.end_extract_date
        )

)

select
    bp_cvrbl_key,
    pol_key,
    pol_line_key,
    cvrbl_type_key,
    end_eff_dt,
    end_exp_dt,
    source_system,
    cvrbl_type_cd,
    prefd_covg_curr_cd,
    coverable_items,
    etl_end_eff_dts,
    etl_end_exp_dts,
    etl_row_eff_dts
from int_gwpc_bop_jurisdiction_cvrbl