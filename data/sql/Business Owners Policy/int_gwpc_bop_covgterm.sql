select * from {{ ref('int_gwpc_bop_covgterm_bldg') }}
union all
select * from {{ ref('int_gwpc_bop_covgterm_polline') }}
union all
select * from {{ ref('int_gwpc_bop_covgterm_sblocation') }}