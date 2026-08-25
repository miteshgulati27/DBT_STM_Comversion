/*
  Parameters used for generating model from template
  'pc_businessautoexcl' table_name
  , 'CA' LOB
  , 'EXCL' CLAUSE_TYPE
  , 'POL_LINE' CVRBL_KEY_SELECTION
  , 'BusinessAutoLine' CVRBL_KEY_TEXT
  , 'BusinessAutoLine' CVRBL_KEY_SRC_COL
  , 'BUSINESSAUTOEXCL' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pc_businessautoexcl' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'EXCL' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'POL_LINE' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'BusinessAutoLine' -%}
{% set cvrbl_key_src_col = 'BusinessAutoLine' -%}
{% set clause_key_text = 'BUSINESSAUTOEXCL' -%}  {# Match clause type #}

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
