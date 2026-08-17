/*
  Parameters used for generating model from template
  'pc_businessautocov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'POL_LINE' CVRBL_KEY_SELECTION
  , 'BusinessAutoLine' CVRBL_KEY_TEXT
  , 'BusinessAutoLine' CVRBL_KEY_SRC_COL
  , 'BUSINESSAUTOCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pc_businessautocov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'POL_LINE' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'BusinessAutoLine' -%}
{% set cvrbl_key_src_col = 'BusinessAutoLine' -%}
{% set clause_key_text = 'BUSINESSAUTOCOV' -%}  {# Match clause type #}

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
