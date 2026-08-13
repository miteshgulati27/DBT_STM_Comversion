

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

bp7_building_latest as (

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
        from "policy_center"."main"."pcx_bp7building" as poll
        inner join "policy_center"."main"."pc_policyperiod" as polper
            on polper.id = poll.branchid
    ) as pccp7
    where pccp7.rn = 1

),

int_gwpc_bop_building_cvrbl as (

    select
        coalesce(nullif(ltrim(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || 'BP7BUILDING' || '-' || cast(src.fixedid as varchar(1000)) as varchar)), ''), '?') as bp_cvrbl_key,
        coalesce(nullif(cast('GWPC' || '-' || cast(polper.periodid as varchar(1000)) as varchar), ''), 'NOKEY') as pol_key,
        coalesce(nullif(cast(case when src.line is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || cast(src.line as varchar(1000)) else null end as varchar), ''), 'NOKEY') as pol_line_key,
        coalesce(nullif(cast('GWPC' || '-' || 'BP7BUILDING' as varchar), ''), 'NOKEY') as cvrbl_type_key,
        cast(coalesce(src.effectivedate, polper.periodstart) as date) as end_eff_dt,
        cast(coalesce(src.expirationdate, polper.periodend) as date) as end_exp_dt,
        coalesce(nullif(ltrim(cast('GWPC' as varchar)), ''), '?') as source_system,
        coalesce(nullif(ltrim(cast('BP7BUILDING' as varchar)), ''), ' ') as cvrbl_type_cd,
        coalesce(nullif(ltrim(cast(preferredcoveragecurrency.typecode as varchar)), ''), ' ') as prefd_covg_curr_cd,
        
        cast(coalesce(src.effectivedate, polper.periodstart) as timestamp) as etl_end_eff_dts,
        cast(coalesce(src.expirationdate, polper.periodend) as timestamp) as etl_end_exp_dts,
        to_json(struct_pack(
            BL_BP_LOC_KEY := coalesce(nullif(cast(case when src.location is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || 'BP7LOCATION' || '-' || cast(src.location as varchar(1000)) else null end as varchar), ''), 'NOKEY'),
            BL_BLDG_KEY := coalesce(nullif(cast(case when src.building is not null then 'GWPC' || '-' || cast(polper.periodid as varchar(1000)) || '-' || cast(src.building as varchar(1000)) else null end as varchar), ''), 'NOKEY'),
            BL_BASEMENT_PRESENT := coalesce(nullif(ltrim(cast(src.bp7basementpresent as varchar)), ''), ' '),
            BL_BLDG_CD_EFF_GRADE := coalesce(nullif(ltrim(cast(src.bp7bldgcodeeffgrade as varchar)), ''), ' '),
            BL_BLDG_CD_EFF_GRADE_CL := coalesce(nullif(ltrim(cast(src.bp7bldgcodeeffgradeclass as varchar)), ''), ' '),
            BL_BLKT_ID_NO := coalesce(src.bp7blktidnumber, 0),
            BL_CERTIFICATE_LEVEL := coalesce(nullif(ltrim(cast(src.bp7certificatelevel as varchar)), ''), ' '),
            BL_CONSTR_TYPE := coalesce(nullif(ltrim(cast(src.bp7constructiontype as varchar)), ''), ' '),
            BL_TEXT := coalesce(nullif(ltrim(cast(src.bp7description as varchar)), ''), ' '),
            BL_IBHS_CERTIFICATE_TYPE := coalesce(nullif(ltrim(cast(src.bp7ibhscertificatetype as varchar)), ''), ' '),
            BL_IS_IT_FINISHED := coalesce(nullif(ltrim(cast(src.bp7isitfinished as varchar)), ''), ' '),
            BL_NO_OF_STORIES := coalesce(src.bp7numberofstories, 0),
            BL_PCT_OWNER_OCCUPIED := coalesce(nullif(ltrim(cast(src.bp7pctowneroccupied as varchar)), ''), ' '),
            BL_PREDOMINANTLY_RESIDENTIAL_AND_FOUR_OR_LESS_UNITS := coalesce(nullif(ltrim(cast(src.bp7predominantlyresidentialfou as varchar)), ''), ' '),
            BL_PROP_TYPE := coalesce(nullif(ltrim(cast(src.bp7propertytype as varchar)), ''), ' '),
            BL_RABOP_TYPE := coalesce(nullif(ltrim(cast(src.bp7rabp7type as varchar)), ''), ' '),
            BL_RABOP_TYPE_LIAB_LESSORS := coalesce(nullif(ltrim(cast(src.bp7rabp7typeliablessors as varchar)), ''), ' '),
            BL_RABOP_WANTED := coalesce(nullif(ltrim(cast(src.bp7rabp7wanted as varchar)), ''), ' '),
            BL_ROOF_TYPE := coalesce(nullif(ltrim(cast(src.bp7rooftype as varchar)), ''), ' '),
            BL_SPRINKLERED := coalesce(nullif(ltrim(cast(src.bp7sprinklered as varchar)), ''), ' '),
            BL_TOT_CONDOMINIUM_BLDG_SQUARE_FOOTAGE := coalesce(src.bp7totalcondominiumbuildingsqu, 0),
            BL_WIND_CL := coalesce(nullif(ltrim(cast(src.bp7windclass as varchar)), ''), ' '),
            BL_WINDSTORM_MITIGATION_DISC_APPLIES := coalesce(nullif(ltrim(cast(src.bp7windstormmitigationdiscount as varchar)), ''), ' '),
            BL_YR_HEATING_REPLACED := coalesce(src.bp7yearheatingreplaced, 0),
            BL_YR_OF_CONSTR := coalesce(src.bp7yearofconstruction, 0),
            BL_YR_PLUMBING_REPLACED := coalesce(src.bp7yearplumbingreplaced, 0),
            BL_YR_ROOFING_REPLACED := coalesce(src.bp7yearroofingreplaced, 0),
            BL_YR_WIRING_REPLACED := coalesce(src.bp7yearwiringreplaced, 0),
            BL_BUILDING_TOTAL_SQUARE_FEET := coalesce(src.bp7buildingtotalsquarefeet, 0),
            BL_INSURED_OCCUPIED_SQUARE_FEET := coalesce(src.bp7insuredoccupiedsquarefeet, 0),
            BL_OCCUPANCY_TYPE := coalesce(nullif(ltrim(cast(src.occupancytype_ext as varchar)), ''), ' '),
            BL_BUILDING_ITV := coalesce(nullif(ltrim(cast(src.buildingitv_ext as varchar)), ''), ' '),
            BL_BUILDING_TOTAL_RCV := coalesce(src.buildingtotalrcv_ext, 0),
            BL_CE_BUILDING_TOTAL_RCV := coalesce(nullif(ltrim(cast(src.cebuildingtotalrcv_ext as varchar)), ''), ' '),
            BL_ROOF_AGE := coalesce(nullif(ltrim(cast(src.bp7roofage as varchar)), ''), ' '),
            BL_BUILDING_CODE := coalesce(nullif(ltrim(cast(src.bp7buildingcode as varchar)), ''), ' '),
            BL_ROOF_DECK := coalesce(nullif(ltrim(cast(src.bp7roofdeck as varchar)), ''), ' '),
            BL_STRUCTURE_TYPE := coalesce(nullif(ltrim(cast(src.bp7structuretype as varchar)), ''), ' '),
            BL_MINE_SUB_SIDENCE_APPLIES := coalesce(nullif(ltrim(cast(src.bp7minesubsidenceapplies as varchar)), ''), ' '),
            BL_ROOF_WALL_CONNECTION := coalesce(nullif(ltrim(cast(src.bp7roofwallconnection as varchar)), ''), ' '),
            BL_ROOF_MATERIAL := coalesce(nullif(ltrim(cast(src.bp7roofmaterial as varchar)), ''), ' '),
            BL_WIND_STORM_INCLUDED := coalesce(nullif(ltrim(cast(src.bp7windstormincluded as varchar)), ''), ' '),
            BL_WATER_RESISTANCE := coalesce(nullif(ltrim(cast(src.bp7waterresistance as varchar)), ''), ' '),
            BL_ROOF_SHAPE := coalesce(nullif(ltrim(cast(src.bp7roofshape as varchar)), ''), ' '),
            BL_DOOR_STRENGTH := coalesce(nullif(ltrim(cast(src.bp7doorstrength as varchar)), ''), ' '),
            BL_LEVEL := coalesce(nullif(ltrim(cast(src.bp7level as varchar)), ''), ' '),
            BL_ROOF_DECK_BUILDING_TYPEII := coalesce(nullif(ltrim(cast(src.bp7roofdeckbuildingtypeii as varchar)), ''), ' '),
            BL_AREA := coalesce(nullif(ltrim(cast(src.bp7area as varchar)), ''), ' '),
            BL_CONSTRUCTED := coalesce(nullif(ltrim(cast(src.bp7constructed as varchar)), ''), ' '),
            BL_ROOF_COVER := coalesce(nullif(ltrim(cast(src.bp7roofcover as varchar)), ''), ' '),
            BL_BUILDING_OCCUPANCY_TYPE := coalesce(nullif(ltrim(cast(src.bp7buildingoccupancytype as varchar)), ''), ' '),
            BL_MINE_SUB_SIDENCE_INSURED_PROPER := coalesce(nullif(ltrim(cast(src.bp7minesubsidenceinsuredproper as varchar)), ''), ' '),
            BL_OCCUPANCY_CLASS := coalesce(nullif(ltrim(cast(src.bp7occupancyclass as varchar)), ''), ' '),
            BL_MINE_SUB_SIDENCE_WAIVED := coalesce(nullif(ltrim(cast(src.bp7minesubsidencewaived as varchar)), ''), ' '),
            BL_SUB_DECKING := coalesce(nullif(ltrim(cast(src.bp7subdecking as varchar)), ''), ' '),
            BL_BUILDING_GROUP := coalesce(nullif(ltrim(cast(src.bp7buildinggroup as varchar)), ''), ' '),
            BL_AGREED_VALUE_OF_BUILDING := coalesce(src.bp7agreedvalueofbuilding, 0),
            BL_OPENING_PROTECTION := coalesce(nullif(ltrim(cast(src.bp7openingprotection as varchar)), ''), ' '),
            BL_COMMERCIAL_CONDOMINIUM := coalesce(nullif(ltrim(cast(src.bp7commercialcondominium as varchar)), ''), ' '),
            BL_IBHS_CERTIFICATE_TYPE_2 := coalesce(nullif(ltrim(cast(src.bp7ibhscertificatetype2 as varchar)), ''), ' '),
            BL_BCEG_CD_EXT := coalesce(nullif(ltrim(cast(src.bcegcode_ext as varchar)), ''), ' '),
            BL_BCEG_ERR_MSG_EXT := coalesce(nullif(ltrim(cast(src.bcegerrormessage_ext as varchar)), ''), ' '),
            BL_BCEG_STAT_EXT_CD := coalesce(nullif(ltrim(cast(bcegstat_ext.typecode as varchar)), ''), ' '),
            BL_CE_SUBSTRUCTURE_TYPE_CD := coalesce(nullif(ltrim(cast(cesubstructuretype.typecode as varchar)), ''), ' '),
            BL_FREIGHT_ELEVATOR_MAT_TYPE_EXT := coalesce(nullif(ltrim(cast(src.freightelevatormattype_ext as varchar)), ''), ' '),
            BL_FREIGHT_ELEVATORS_EXT := coalesce(src.freightelevators_ext, 0),
            BL_OCCPNCY_CD_EXT := coalesce(nullif(ltrim(cast(src.occupancycode_ext as varchar)), ''), ' '),
            BL_OCCPNCY_TEXT_EXT := coalesce(nullif(ltrim(cast(src.occupancydescription_ext as varchar)), ''), ' '),
            BL_OVRD_OCC_CD_EXT_FL := coalesce(
        case
            when cast(src.overrideocccode_ext as varchar) = '1' then 'Y'
            when cast(src.overrideocccode_ext as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            BL_PASS_ELEVATOR_MAT_TYPE_EXT := coalesce(nullif(ltrim(cast(src.passelevatormattype_ext as varchar)), ''), ' '),
            BL_PSNGR_ELEVATORS_EXT := coalesce(src.passengerelevators_ext, 0),
            BL_PREFD_STTLMNT_CURR_CD := coalesce(nullif(ltrim(cast(preferredsettlementcurrency.typecode as varchar)), ''), ' '),
            BL_SPRINKLER_MATERIAL_TYPE_EXT := coalesce(nullif(ltrim(cast(src.sprinklermaterialtype_ext as varchar)), ''), ' '),
            BL_SPRINKLER_PCT_EXT := coalesce(src.sprinklerpercentage_ext, 0),
            BL_SUBSTRUCTURE_AREA_EXT := coalesce(src.substructurearea_ext, 0),
            BL_UPDATE_BCEG_EXT_FL := coalesce(
        case
            when cast(src.updatebceg_ext as varchar) = '1' then 'Y'
            when cast(src.updatebceg_ext as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            BL_UPDATE_ITV_EXT_FL := coalesce(
        case
            when cast(src.updateitv_ext as varchar) = '1' then 'Y'
            when cast(src.updateitv_ext as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            BL_USER_UPDATED_COVG_CURR_FL := coalesce(
        case
            when cast(src.userupdatedcoveragecurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedcoveragecurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            BL_USER_UPDATED_STTLMNT_CURR_FL := coalesce(
        case
            when cast(src.userupdatedsettlementcurrency as varchar) = '1' then 'Y'
            when cast(src.userupdatedsettlementcurrency as varchar) = '0' then 'N'
            else null
        end,
        'U'
    ),
            BL_VACANT_SQUARE_FEET_EXT := coalesce(src.bp7vacantsquarefeet, 0)
        )) as coverable_items,
        
        job.closedate as etl_row_eff_dts
    from "policy_center"."main"."pcx_bp7building" as src
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
    left join "policy_center"."main"."pctl_bcegstatus_ext" as bcegstat_ext
        on bcegstat_ext.id = src.bcegstat_ext
    left join "policy_center"."main"."pctl_substructuretype_ext" as cesubstructuretype
        on cesubstructuretype.id = src.cesubstructuretype
    left join bp7_building_latest as srcx
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
from int_gwpc_bop_building_cvrbl