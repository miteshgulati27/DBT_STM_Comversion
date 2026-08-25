/*
  Parameters used for generating model from template
  'pcx_ca7grsschedcovitemcov' table_name
  , 'CA' LOB
  , 'COVG' CLAUSE_TYPE
  , 'CVRBL_KEY' CVRBL_KEY_SELECTION
  , 'CA7GrsSchedCovItem' CVRBL_KEY_TEXT
  , 'CA7GrsSchedCovItem' CVRBL_KEY_SRC_COL
  , 'CA7GRSSCHEDCOVITEMCOV' CLAUSE_KEY_TEXT
*/

{% set term_table_name = 'pcx_ca7grsschedcovitemcov' -%}
{% set lob = 'CA' -%}
{% set clause_type = 'COVG' -%}
{% set cvrbl_key = 'CVRBL_KEY' -%}
{% set cvrbl_key_text = 'CA7GrsSchedCovItem' -%}
{% set cvrbl_key_src_col = 'CA7GrsSchedCovItem' -%}
{% set clause_key_text = 'CA7GRSSCHEDCOVITEMCOV' -%}

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
