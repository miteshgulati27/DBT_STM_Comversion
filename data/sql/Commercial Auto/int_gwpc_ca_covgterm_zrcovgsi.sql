/*
  Parameters used for generating model from template
  'pcx_ca7zrschedcovitemcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7ZrSchedCovItem' CVRBL_KEY_TEXT
  , 'CA7ZrSchedCovItem' CVRBL_KEY_SRC_COL
  , 'CA7ZRSCHEDCOVITEMCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7zrschedcovitemcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}
{% set cvrbl_key = 'CVRBL_KEY' -%}
{% set cvrbl_key_text = 'CA7ZrSchedCovItem' -%}
{% set cvrbl_key_src_col = 'CA7ZrSchedCovItem' -%}
{% set clause_key_text = 'CA7ZRSCHEDCOVITEMCOV' -%}

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
