select * from {{ ref('int_gwpc_ca_condterm_dealer') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_garagesvc') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_juris') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_namedind') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_policyline') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_privpas') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_publictrans') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_specialtype') }}
union all
select * from {{ ref('int_gwpc_ca_condterm_truck') }}
