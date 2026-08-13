/*
  Parameters used for generating model from template
  'pcx_ca7truckcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CATRUCK' CVRBL_KEY_TEXT
  , 'Truck' CVRBL_KEY_SRC_COL
  , 'CATRUCKCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7truckcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'CVRBL_KEY' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'CA7Truck' -%}
{% set cvrbl_key_src_col = 'Truck' -%}
{% set clause_key_text = 'CA7TRUCKCOV' -%}  {# Match clause type #}

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