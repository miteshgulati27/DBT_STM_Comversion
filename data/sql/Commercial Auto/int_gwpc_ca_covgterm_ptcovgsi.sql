/*
  Parameters used for generating model from template
  'pcx_ca7ptschedcovitemcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7PtSchedCovItem' CVRBL_KEY_TEXT
  , 'CA7PtSchedCovItem' CVRBL_KEY_SRC_COL
  , 'CA7PTSCHEDCOVITEMCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7ptschedcovitemcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}
{% set cvrbl_key = 'CVRBL_KEY' -%}
{% set cvrbl_key_text = 'CA7PtSchedCovItem' -%}
{% set cvrbl_key_src_col = 'CA7PtSchedCovItem' -%}
{% set clause_key_text = 'CA7PTSCHEDCOVITEMCOV' -%}

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
