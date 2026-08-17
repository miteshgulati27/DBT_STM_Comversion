/*
  Parameters used for generating model from template
  'pc_businessautocond' table_name
  , 'CA' LOB
  , 'COND' CLAUSE_TYPE
  , 'POL_LINE' CVRBL_KEY_SELECTION
  , 'BusinessAutoLine' CVRBL_KEY_TEXT
  , 'BusinessAutoLine' CVRBL_KEY_SRC_COL
  , 'BUSINESSAUTOCOND' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pc_businessautocond' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COND' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'POL_LINE' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'BusinessAutoLine' -%}
{% set cvrbl_key_src_col = 'BusinessAutoLine' -%}
{% set clause_key_text = 'BUSINESSAUTOCOND' -%}  {# Match clause type #}

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
