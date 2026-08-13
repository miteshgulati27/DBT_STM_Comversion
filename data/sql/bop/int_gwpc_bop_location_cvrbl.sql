

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

bp7_location_latest as (

    select
        pccp7.branchid,
        pccp7.fixedid,
        pccp7.id
    from (
        select
            poll.branchid,
            poll.fixedid,
            poll.id,
            row_number() over (
                partition by poll.branchid, poll.fixedid
                order by poll.expirationdate desc
            ) as rn
        from "policy_center"."main"."pcx_bp7location" as poll
        inner join "policy_center"."main"."pc_policyperiod" as polper
            on polper.id = poll.branchid
    ) as pccp7
    where pccp7.rn = 1

),

int_gwpc_bop_location_cvrbl as (

    select
        coalesce(nullif(ltrim(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || 'BP7LOCATION' || '-' || cast(src.fixedid as varchar(1000)) as varchar)), ''), '?') as bp_cvrbl_key,
        coalesce(nullif(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) as varchar), ''), 'NOKEY') as pol_key,
        coalesce(nullif(cast(case when src.line is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || cast(src.line as varchar(1000)) else null end as varchar), ''), 'NOKEY') as pol_line_key,
        coalesce(nullif(cast('GWPC' || '-' || 'BP7LOCATION' as varchar), ''), 'NOKEY') as cvrbl_type_key,
        cast(coalesce(src.effectivedate, polper.periodstart) as date) as end_eff_dt,
        cast(coalesce(src.expirationdate, polper.periodend) as date) as end_exp_dt,
        coalesce(nullif(ltrim(cast('GWPC' as varchar)), ''), '?') as source_system,
        coalesce(nullif(ltrim(cast('BP7LOCATION' as varchar)), ''), ' ') as cvrbl_type_cd,
        coalesce(nullif(ltrim(cast(preferredcoveragecurrency.typecode as varchar)), ''), ' ') as prefd_covg_curr_cd,
        
        cast(coalesce(src.effectivedate, polper.periodstart) as timestamp) as etl_end_eff_dts,
        cast(coalesce(src.expirationdate, polper.periodend) as timestamp) as etl_end_exp_dts,
        to_json(struct_pack(
            LO_LOC_KEY := coalesce(nullif(cast(case when src.location is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || cast(src.location as varchar(1000)) else null end as varchar), ''), 'NOKEY'),
            LO_CITY := coalesce(nullif(ltrim(cast(src.bp7city as varchar)), ''), ' '),
            LO_COUNTY := coalesce(nullif(ltrim(cast(src.bp7county as varchar)), ''), ' '),
            LO_FEET_TO_HYDRANT := coalesce(nullif(ltrim(cast(src.bp7feettohydrant as varchar)), ''), ' '),
            LO_FIRE_PROT_CL_PPC := coalesce(nullif(ltrim(cast(src.bp7fireprotectionclassppc as varchar)), ''), ' '),
            LO_IS_DIST_FIRE_HYDRANT_AVL_EXT_FL := coalesce(
        case
            when cast(src.isdistanttofirehydrantavl_ext as varchar) = '1' then 'Y'
            when cast(src.isdistanttofirehydrantavl_ext as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            LO_OLD_PROTECT_CL_EXT := coalesce(nullif(ltrim(cast(src.oldprotectclass_ext as varchar)), ''), ' '),
            LO_OVRD_PPC_EXT_FL := coalesce(
        case
            when cast(src.overrideppc_ext as varchar) = '1' then 'Y'
            when cast(src.overrideppc_ext as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            LO_PPC_STATUS_EXT_CD := coalesce(nullif(ltrim(cast(ppcstatus_ext.typecode as varchar)), ''), ' '),
            LO_PRIV_FIRE_DEPT := coalesce(nullif(ltrim(cast(src.bp7privfiredept as varchar)), ''), ' '),
            LO_RATING_TERR := coalesce(nullif(ltrim(cast(src.bp7ratingterritory as varchar)), ''), ' '),
            LO_UNIT_NO := coalesce(src.bp7unitnumber, 0),
            LO_ZIP_CD := coalesce(nullif(ltrim(cast(src.bp7zipcode as varchar)), ''), ' '),
            LO_EQ_TERR_EXT := coalesce(nullif(ltrim(cast(src.bp7eqterr as varchar)), ''), ' '),
            LO_PREFD_STTLMNT_CURR_CD := coalesce(nullif(ltrim(cast(preferredsettlementcurrency.typecode as varchar)), ''), ' '),
            LO_USER_UPDATED_COVG_CURR_FL := coalesce(
        case
            when cast(src.userupdatedcoveragecurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedcoveragecurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            LO_USER_UPDATED_STTLMNT_CURR_FL := coalesce(
        case
            when cast(src.userupdatedsettlementcurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedsettlementcurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    )
        )) as coverable_items,
        
        job.closedate as etl_row_eff_dts
    from "policy_center"."main"."pcx_bp7location" as src
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
    left join "policy_center"."main"."pctl_ppcstatus_ext" as ppcstatus_ext
        on ppcstatus_ext.id = src.ppcstatus_ext
    left join bp7_location_latest as srcx
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
from int_gwpc_bop_location_cvrbl