/*
  Parameters used for generating model from template
  'pcx_ca7namedindexcl' table_name
  , 'CA' LOB
  , 'EXCL' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7NamedInd' CVRBL_KEY_TEXT
  , 'NamedInd' CVRBL_KEY_SRC_COL
  , 'CA7NAMEDINDEXCL' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7namedindexcl' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'EXCL' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'CVRBL_KEY' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'CA7NamedInd' -%}
{% set cvrbl_key_src_col = 'NamedInd' -%}
{% set clause_key_text = 'CA7NAMEDINDEXCL' -%}  {# Match clause type #}

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
