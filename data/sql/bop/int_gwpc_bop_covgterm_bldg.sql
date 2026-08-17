-- depends_on: {{ ref('etl_control_parm') }}


{%- set term_table_name = 'pc_bopbuildingcov' -%}
{%- set lob = 'BOP' -%}
{%- set clause_type = 'COVG' -%}
{%- set cvrbl_key = 'CVRBL_KEY' -%}
{%- set cvrbl_key_text = 'BOPBuilding' -%}
{%- set cvrbl_key_src_col = 'BUILDING' -%}
{%- set clause_key_text = 'BOPBuildingCov' -%}

{{ m_int_term(term_table_name, lob, clause_type, cvrbl_key, cvrbl_key_text, cvrbl_key_src_col, clause_key_text) }}