

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

bp7_classification_latest as (

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
        from "policy_center"."main"."pcx_bp7classification" as poll
        inner join "policy_center"."main"."pc_policyperiod" as polper
            on polper.id = poll.branchid
    ) as pccp7
    where pccp7.rn = 1

),

int_gwpc_bop_classification_cvrbl as (

    select
        coalesce(nullif(ltrim(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || 'BP7CLASSIFICATION' || '-' || cast(src.fixedid as varchar(1000)) as varchar)), ''), '?') as bp_cvrbl_key,
        coalesce(nullif(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) as varchar), ''), 'NOKEY') as pol_key,
        coalesce(nullif(cast(case when src.line is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || cast(src.line as varchar(1000)) else null end as varchar), ''), 'NOKEY') as pol_line_key,
        coalesce(nullif(cast('GWPC' || '-' || 'BP7CLASSIFICATION' as varchar), ''), 'NOKEY') as cvrbl_type_key,
        cast(coalesce(src.effectivedate, polper.periodstart) as date) as end_eff_dt,
        cast(coalesce(src.expirationdate, polper.periodend) as date) as end_exp_dt,
        coalesce(nullif(ltrim(cast('GWPC' as varchar)), ''), '?') as source_system,
        coalesce(nullif(ltrim(cast('BP7CLASSIFICATION' as varchar)), ''), ' ') as cvrbl_type_cd,
        coalesce(nullif(ltrim(cast(preferredcoveragecurrency.typecode as varchar)), ''), ' ') as prefd_covg_curr_cd,
        
        cast(coalesce(src.effectivedate, polper.periodstart) as timestamp) as etl_end_eff_dts,
        cast(coalesce(src.expirationdate, polper.periodend) as timestamp) as etl_end_exp_dts,
        to_json(struct_pack(
            CL_BP_BLDG_KEY := coalesce(nullif(cast(case when src.building is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || 'BP7BUILDING' || '-' || cast(src.building as varchar(1000)) else null end as varchar), ''), 'NOKEY'),
            CL_AREA := coalesce(src.bp7area, 0),
            CL_BLKT_ID_NO := coalesce(src.bp7blktidnumber, 0),
            CL_CL_CD := coalesce(nullif(ltrim(cast(src.bp7classcode as varchar)), ''), ' '),
            CL_CL_TEXT := coalesce(nullif(ltrim(cast(src.bp7classdescription as varchar)), ''), ' '),
            CL_CL_GRP := coalesce(nullif(ltrim(cast(src.bp7classgroup as varchar)), ''), ' '),
            CL_CL_PROP_TYPE := coalesce(nullif(ltrim(cast(src.bp7classpropertytype as varchar)), ''), ' '),
            CL_CLASS_NO := coalesce(src.classificationnumber, 0),
            CL_CONDO_BYLAWS := coalesce(nullif(ltrim(cast(src.bp7condobylaws as varchar)), ''), ' '),
            CL_CONDO_RESIDENCE := coalesce(nullif(ltrim(cast(src.bp7condoresidence as varchar)), ''), ' '),
            CL_TEXT_OF_PROP_OR_COVG := coalesce(nullif(ltrim(cast(src.bp7descriptionofpropertyor as varchar)), ''), ' '),
            CL_EXPSR := coalesce(src.bp7exposure, 0),
            CL_EXPSR_BASIS := coalesce(nullif(ltrim(cast(src.bp7exposurebasis as varchar)), ''), ' '),
            CL_FUNCTL_BUSN_PRSNL_PROP_VALTN_APPLY := coalesce(nullif(ltrim(cast(src.bp7functlbusnprsnlpropvaltnapp as varchar)), ''), ' '),
            CL_NORTH_AMERICAN_INDUSTRY_CLASS_SYS_NAICS_CD := coalesce(nullif(ltrim(cast(src.bp7northamericanindustryclassi as varchar)), ''), ' '),
            CL_PREDOMINANT_FL := coalesce(
        case
            when cast(src.predominant as varchar) = '1' then 'Y'
            when cast(src.predominant as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            CL_RABOP_TYPE := coalesce(nullif(ltrim(cast(src.bp7rabp7type as varchar)), ''), ' '),
            CL_RABOP_TYPE_LIAB_OCCUPANTS := coalesce(nullif(ltrim(cast(src.bp7rabp7typeliaboccupants as varchar)), ''), ' '),
            CL_RABOP_WANTED := coalesce(nullif(ltrim(cast(src.bp7rabp7wanted as varchar)), ''), ' '),
            CL_RATE_NO := coalesce(src.bp7ratenumber, 0),
            CL_STD_INDUSTRIAL_CLASS_SIC_CD := coalesce(nullif(ltrim(cast(src.bp7standardindustrialclassific as varchar)), ''), ' '),
            CL_TOWN_HOUSE_BY_LAW := coalesce(nullif(ltrim(cast(src.bp7townhousebylaw as varchar)), ''), ' '),
            CL_PLUMBING_LICENSE := coalesce(nullif(ltrim(cast(src.bp7plumbinglicense as varchar)), ''), ' '),
            CL_TOWN_HOUSE_ASSOC := coalesce(nullif(ltrim(cast(src.bp7townhouseassoc as varchar)), ''), ' '),
            CL_CONTRACTORS_WORK := coalesce(nullif(ltrim(cast(src.bp7contractorswork as varchar)), ''), ' '),
            CL_AUDITED_EXPSR_EXT := coalesce(src.auditedexposure_ext, 0),
            CL_BUS_CERT_EXT := coalesce(nullif(ltrim(cast(src.businesscertified_ext as varchar)), ''), ' '),
            CL_CNTRCT_IA_CD_CH_EXT := coalesce(nullif(ltrim(cast(src.cntrctiacodech_ext as varchar)), ''), ' '),
            CL_CONDO_LAW_DEC_EXT := coalesce(nullif(ltrim(cast(src.bp7condolawdec_ext as varchar)), ''), ' '),
            CL_CONDO_LAW_PROJ_EXT := coalesce(nullif(ltrim(cast(src.bp7condolawproj_ext as varchar)), ''), ' '),
            CL_EQ_FCTR_EXT := coalesce(src.earthquakefactor_ext, 0),
            CL_EQ_SUB_LMT_FCTR_EXT := coalesce(src.earthquakesublimitfactor_ext, 0),
            CL_IF_ANY_BASIS_EXT := coalesce(nullif(ltrim(cast(src.ifanybasis_ext as varchar)), ''), ' '),
            CL_NO_OF_CAR_WASH_BAYS_EXT := coalesce(src.noofcarwashbays_ext, 0),
            CL_NO_OF_FUEL_PUMPS_EXT := coalesce(src.nooffuelpumps_ext, 0),
            CL_PEST_HERB_POLL_EXT := coalesce(nullif(ltrim(cast(src.bp7pestherbpoll_ext as varchar)), ''), ' '),
            CL_PREFD_STTLMNT_CURR_CD := coalesce(nullif(ltrim(cast(preferredsettlementcurrency.typecode as varchar)), ''), ' '),
            CL_USER_UPDATED_COVG_CURR_FL := coalesce(
        case
            when cast(src.userupdatedcoveragecurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedcoveragecurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            CL_USER_UPDATED_STTLMNT_CURR_FL := coalesce(
        case
            when cast(src.userupdatedsettlementcurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedsettlementcurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    )
        )) as coverable_items,
        
        job.closedate as etl_row_eff_dts
    from "policy_center"."main"."pcx_bp7classification" as src
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
    left join bp7_classification_latest as srcx
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
from int_gwpc_bop_classification_cvrbl