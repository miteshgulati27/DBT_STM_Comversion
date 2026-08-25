/*
  Parameters used for generating model from template
  'pcx_ca7publictransexcl' table_name
  , 'CA' LOB
  , 'EXCL' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7PublicTransport' CVRBL_KEY_TEXT
  , 'PublicTransport' CVRBL_KEY_SRC_COL
  , 'CA7PUBLICTRANSEXCL' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7publictransexcl' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'EXCL' -%}   {# 'COVG','COND','EXCL'#}
{% set cvrbl_key = 'CVRBL_KEY' -%} {# 'CVRBL_KEY','POL_LINE','NEITHER'#}
{% set cvrbl_key_text = 'CA7PublicTransport' -%}
{% set cvrbl_key_src_col = 'PublicTransport' -%}
{% set clause_key_text = 'CA7PUBLICTRANSEXCL' -%}  {# Match clause type #}

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
