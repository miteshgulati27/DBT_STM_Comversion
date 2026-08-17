/*
  Parameters used for generating model from template
  'pcx_ca7jrschedcovitemcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7JrSchedCovItem' CVRBL_KEY_TEXT
  , 'CA7JrSchedCovItem' CVRBL_KEY_SRC_COL
  , 'CA7JRSCHEDCOVITEMCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7jrschedcovitemcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}
{% set cvrbl_key = 'CVRBL_KEY' -%}
{% set cvrbl_key_text = 'CA7JrSchedCovItem' -%}
{% set cvrbl_key_src_col = 'CA7JrSchedCovItem' -%}
{% set clause_key_text = 'CA7JRSCHEDCOVITEMCOV' -%}

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
