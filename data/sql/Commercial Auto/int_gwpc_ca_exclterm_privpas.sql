/*
  Parameters used for generating model from template
  'pcx_ca7privpasexcl' table_name
  , 'CA' LOB
  , 'EXCL' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7PrivatePassenger' CVRBL_KEY_TEXT
  , 'PrivatePassenger' CVRBL_KEY_SRC_COL
  , 'CA7PRIVPASEXCL' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7privpasexcl' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'EXCL' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'CVRBL_KEY' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'CA7PrivatePassenger' -%}
{% set cvrbl_key_src_col = 'PrivatePassenger' -%}
{% set clause_key_text = 'CA7PRIVPASEXCL' -%}  {# Match clause type #}

{{
    config(
        materialized='table'
    )
}}

{{ m_int_term(
    term_table_name,
    lob,
    clause_type,
    cvrbl_key,
    cvrbl_key_text,
    cvrbl_key_src_col,
    clause_key_text
) }}
