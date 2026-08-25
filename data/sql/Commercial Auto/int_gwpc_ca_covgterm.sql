select * from {{ ref('int_gwpc_ca_covgterm_dealer') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_garagesvc') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_juris') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_namedind') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_policyline') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_privpas') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_publictrans') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_specialtype') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_truck') }}
union all
select * from {{ ref('int_gwpc_ca_covgterm_zonerated') }}
