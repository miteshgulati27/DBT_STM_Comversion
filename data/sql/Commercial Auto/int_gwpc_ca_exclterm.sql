select * from {{ ref('int_gwpc_ca_exclterm_dealer') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_garagesvc') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_juris') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_namedind') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_policyline') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_privpas') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_publictrans') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_specialtype') }}
union all
select * from {{ ref('int_gwpc_ca_exclterm_truck') }}
