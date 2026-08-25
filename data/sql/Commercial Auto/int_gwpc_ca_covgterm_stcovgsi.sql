/*
  Parameters used for generating model from template
  'pcx_ca7stschedcovitemcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7StSchedCovItem' CVRBL_KEY_TEXT
  , 'CA7StSchedCovItem' CVRBL_KEY_SRC_COL
  , 'CA7STSCHEDCOVITEMCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7stschedcovitemcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}
{% set cvrbl_key = 'CVRBL_KEY' -%}
{% set cvrbl_key_text = 'CA7StSchedCovItem' -%}
{% set cvrbl_key_src_col = 'CA7StSchedCovItem' -%}
{% set clause_key_text = 'CA7STSCHEDCOVITEMCOV' -%}

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
