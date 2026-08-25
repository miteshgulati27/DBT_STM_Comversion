select * from {{ ref('int_gwpc_ca_privpas_cvrbl') }}
union all
select * from {{ ref('int_gwpc_ca_publictrans_cvrbl') }}
union all
select * from {{ ref('int_gwpc_ca_specialtype_cvrbl') }}
union all
select * from {{ ref('int_gwpc_ca_truck_cvrbl') }}
union all
select * from {{ ref('int_gwpc_ca_zonerated_cvrbl') }}
