/*
  Parameters used for generating model from template
  'pcx_ca7dealercond' table_name
  , 'CA' LOB
  , 'COND' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7Dealer' CVRBL_KEY_TEXT
  , 'Dealer' CVRBL_KEY_SRC_COL
  , 'CA7DEALERCOND' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7dealercond' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COND' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'CVRBL_KEY' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'CA7Dealer' -%}
{% set cvrbl_key_src_col = 'Dealer' -%}
{% set clause_key_text = 'CA7DEALERCOND' -%}  {# Match clause type #}

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
