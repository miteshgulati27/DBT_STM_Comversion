/*
  Parameters used for generating model from template
  'pcx_ca7jurisdictioncond' table_name
  , 'CA' LOB
  , 'COND' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7Jurisdiction' CVRBL_KEY_TEXT
  , 'Jurisdiction' CVRBL_KEY_SRC_COL
  , 'CA7JURISDICTIONCOND' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7jurisdictioncond' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COND' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'CVRBL_KEY' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'CA7Jurisdiction' -%}
{% set cvrbl_key_src_col = 'Jurisdiction' -%}
{% set clause_key_text = 'CA7JURISDICTIONCOND' -%}  {# Match clause type #}

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
