/*
  Parameters used for generating model from template
  'pcx_ca7trschedcovitemcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7TrSchedCovItem' CVRBL_KEY_TEXT
  , 'CA7TrSchedCovItem' CVRBL_KEY_SRC_COL
  , 'CA7TRSCHEDCOVITEMCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7trschedcovitemcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}
{% set cvrbl_key = 'CVRBL_KEY' -%}
{% set cvrbl_key_text = 'CA7TrSchedCovItem' -%}
{% set cvrbl_key_src_col = 'CA7TrSchedCovItem' -%}
{% set clause_key_text = 'CA7TRSCHEDCOVITEMCOV' -%}

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
