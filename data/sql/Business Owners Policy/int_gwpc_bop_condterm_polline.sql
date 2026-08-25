
{%- set term_table_name = 'pcx_bopbopcond' -%}
{%- set lob = 'BOP' -%}
{%- set clause_type = 'COND' -%}
{%- set cvrbl_key = 'POL_LINE' -%}
{%- set cvrbl_key_text = 'BusinessOwnersLine' -%}
{%- set cvrbl_key_src_col = 'BusinessOwnersLine' -%}
{%- set clause_key_text = 'BusinessOwnersCond' -%}

{{ m_int_term(term_table_name, lob, clause_type, cvrbl_key, cvrbl_key_text, cvrbl_key_src_col, clause_key_text) }}