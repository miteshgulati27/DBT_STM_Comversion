select * from {{ ref('int_gwpc_ca_scheditem_line_cond') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_line_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_line_excl') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_dealer_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_dealer_excl') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_garagesvc_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_juris_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_juris_excl') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_pp_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_pt_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_st_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_truck_covg') }}
union all
select * from {{ ref('int_gwpc_ca_scheditem_zr_covg') }}
